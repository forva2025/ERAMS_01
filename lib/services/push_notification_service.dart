import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/config/firebase_options.dart';
import 'supabase_service.dart';

/// Web push requires a VAPID key from Firebase Console → Cloud Messaging →
/// Web configuration (see firebase_options.dart's setup comment). Passed at
/// build time, same --dart-define convention as Agora's app ID/Supabase keys.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

const _defaultChannel = AndroidNotificationChannel(
  'erams_default',
  'ERAMS Notifications',
  description: 'Trip and dispatch updates',
  importance: Importance.high,
);

// Loud, distinct channel for incoming calls — needs its own channel because
// Android notification *sound* is a channel-level setting the app cannot
// override per-notification once the channel exists. The referenced sound
// file lives at android/app/src/main/res/raw/ringtone.mp3 (a native raw
// resource, separate from the Flutter-asset ringtone IncomingCallScreen
// loops in-app while the app is foregrounded).
const _incomingCallChannel = AndroidNotificationChannel(
  'erams_incoming_call',
  'Incoming Calls',
  description: 'Rings when a driver or patient is calling you',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('ringtone'),
  playSound: true,
  enableVibration: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be a top-level function (not a closure/method) — this is an
/// `firebase_messaging` requirement, since it runs in a separate isolate
/// when a data message arrives while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] as String?;
  final isCall = type == 'incoming_call';
  final channel = isCall ? _incomingCallChannel : _defaultChannel;

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await _localNotifications.show(
    data['notificationId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    data['title'] as String? ?? 'ERAMS',
    data['body'] as String? ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        sound: channel.sound,
        playSound: channel.playSound,
        enableVibration: channel.enableVibration,
      ),
    ),
    payload: data['payload'] as String?,
  );
}

class PushNotificationService {
  bool _foregroundInitialized = false;

  Future<void> initializeForegroundHandling() async {
    if (!DefaultFirebaseOptions.isConfigured || _foregroundInitialized) return;
    _foregroundInitialized = true;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.createNotificationChannel(_incomingCallChannel);
    // Android 13+ requires runtime POST_NOTIFICATIONS permission. Uses
    // permission_handler (already a dependency for Agora mic/camera
    // permissions in call_screen.dart) rather than this old
    // flutter_local_notifications version's Android plugin, which predates
    // its own requestNotificationsPermission() API.
    if (!kIsWeb) await Permission.notification.request();

    await FirebaseMessaging.instance.requestPermission();

    // FCM never auto-displays a data-only message while the app is
    // foregrounded (that's the whole point of sending data-only — see
    // send_push_notification's comment) — show it ourselves.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerCurrentToken());
  }

  Future<void> registerCurrentToken() async {
    if (!DefaultFirebaseOptions.isConfigured) return;
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey)
          : await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';

      await supabaseClient.from('device_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': platform,
          'last_seen_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
    } catch (_) {
      // Best-effort — a failed token registration just means this device
      // won't receive push until the next successful attempt (app relaunch,
      // token refresh); never block sign-in on it.
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!DefaultFirebaseOptions.isConfigured) return;
    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey)
          : await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await supabaseClient.from('device_tokens').delete().eq('fcm_token', token);
    } catch (_) {
      // Best-effort — see registerCurrentToken().
    }
  }
}
