import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

/// Realtime-backed feed of the current user's notifications, newest first.
/// Mirrors DriverIncidentNotifier's Realtime pattern (driver_provider.dart)
/// but scoped by user_id instead of ambulance_id.
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AppNotification>> build() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return const [];

    _subscribeRealtime(userId);
    ref.onDispose(() => _channel?.unsubscribe());
    return NotificationService().fetchRecent();
  }

  void _subscribeRealtime(String userId) {
    _channel = supabaseClient
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = AppNotification.fromJson(payload.newRecord);
            state = AsyncData([row, ...(state.valueOrNull ?? const [])]);
          },
        )
        .subscribe();
  }

  Future<void> markRead(String id) async {
    await NotificationService().markRead(id);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final n in current)
        if (n.id == id)
          AppNotification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          )
        else
          n,
    ]);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Count of unread notifications, derived from [notificationsProvider].
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.isRead).length;
});
