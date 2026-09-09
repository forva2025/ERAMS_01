import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'supabase_service.dart';

/// Full Agora RTC implementation used on Android / iOS / desktop.
class AgoraService {
  /// Compile-time fallback App ID (`--dart-define=AGORA_APP_ID=...`). The
  /// server-issued value from the token endpoint takes precedence so the App ID
  /// used to *join* can never disagree with the one the token was *signed* for
  /// — a mismatch is one of the two ways Agora raises error 110 (invalid token).
  static const _fallbackAppId = String.fromEnvironment('AGORA_APP_ID');

  RtcEngine? _engine;
  bool _localJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _videoEnabled = true;
  bool _speakerEnabled = true;

  // Remembered so a token-renewal can re-fetch for the same channel.
  String? _currentChannel;

  // Callbacks — set by the call screen
  void Function(int uid)? onUserJoined;
  void Function(int uid)? onUserOffline;
  void Function()? onJoined;
  void Function(int code, String msg)? onError;

  bool get isInitialized => _engine != null;
  bool get localJoined => _localJoined;
  int? get remoteUid => _remoteUid;
  bool get isMuted => _muted;
  bool get isVideoEnabled => _videoEnabled;
  bool get isSpeakerEnabled => _speakerEnabled;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize({String? appId, bool withVideo = true}) async {
    final resolvedAppId =
        (appId != null && appId.isNotEmpty) ? appId : _fallbackAppId;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: resolvedAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
      audioScenario: AudioScenarioType.audioScenarioDefault,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        _localJoined = true;
        onJoined?.call();
      },
      onUserJoined: (RtcConnection connection, int uid, int elapsed) {
        _remoteUid = uid;
        onUserJoined?.call(uid);
      },
      onUserOffline: (RtcConnection connection, int uid,
          UserOfflineReasonType reason) {
        if (_remoteUid == uid) _remoteUid = null;
        onUserOffline?.call(uid);
      },
      // Fires ~30s before the token expires. Re-fetch and renew so long calls
      // are not dropped with a token-expired error mid-conversation.
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
        final channel = _currentChannel;
        if (channel == null) return;
        final creds = await _fetchCredentials(channel);
        if (creds.token != null && creds.token!.isNotEmpty) {
          await _engine?.renewToken(creds.token!);
        }
      },
      onError: (ErrorCodeType code, String msg) {
        // code.value() is the real Agora error number (e.g. 110). Do NOT use
        // code.index — that is the enum's ordinal position (110 → index 25),
        // which is what previously surfaced as the misleading "Call error(25)".
        final agoraCode = code.value();
        debugPrint('[Agora] error $agoraCode ($code): $msg');
        onError?.call(agoraCode, _describeError(agoraCode, msg));
      },
    ));

    if (withVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }
    // setEnableSpeakerphone() switches the *active* audio route and requires
    // a live session — calling it before joinChannel() throws ERR_NOT_READY
    // (-3) on Android. setDefaultAudioRouteToSpeakerphone() sets the default
    // route pre-join instead, which is what's needed here.
    await _engine!.setDefaultAudioRouteToSpeakerphone(true);
  }

  Future<void> joinChannel(String channelId, {bool withVideo = true}) async {
    _currentChannel = channelId;

    // Fetch credentials first so the engine can be initialised with the same
    // App ID the token was signed for.
    final creds = await _fetchCredentials(channelId);

    if (_engine == null) {
      await initialize(appId: creds.appId, withVideo: withVideo);
    }

    await _engine!.joinChannel(
      token: creds.token ?? '',
      channelId: channelId,
      uid: 0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: withVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: withVideo,
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
  }

  Future<void> toggleVideo() async {
    _videoEnabled = !_videoEnabled;
    await _engine?.muteLocalVideoStream(!_videoEnabled);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    _speakerEnabled = !_speakerEnabled;
    await _engine?.setEnableSpeakerphone(_speakerEnabled);
  }

  Future<void> leave() async {
    await _engine?.leaveChannel();
    _localJoined = false;
    _remoteUid = null;
    _muted = false;
    _videoEnabled = true;
    _currentChannel = null;
  }

  Future<void> dispose() async {
    await _engine?.release();
    _engine = null;
  }

  // ── Video view builders (called by call_screen.dart) ──────────────────────

  Widget localVideoView() {
    if (_engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget remoteVideoView(int uid, String channelId) {
    if (_engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<_AgoraCredentials> _fetchCredentials(String channelName) async {
    try {
      final resp = await supabaseClient.functions.invoke(
        'generate_agora_token',
        body: {'channelName': channelName, 'uid': 0},
      );
      final data = resp.data as Map<String, dynamic>?;
      return _AgoraCredentials(
        appId: data?['appId'] as String?,
        token: data?['token'] as String?,
      );
    } catch (e) {
      // Falls back to compile-time App ID + empty token — this only connects if
      // the Agora project has no App Certificate (Testing Mode). If a
      // certificate is enabled the join will fail with error 110 until the
      // token endpoint is reachable.
      debugPrint('[Agora] token fetch failed: $e');
      return const _AgoraCredentials(appId: null, token: null);
    }
  }

  /// Turns the raw Agora error number into something a user can act on.
  String _describeError(int code, String rawMsg) {
    switch (code) {
      case 101:
        return 'Invalid Agora App ID. Check AGORA_APP_ID configuration.';
      case 109:
      case 110:
        return 'Call authentication failed (token invalid or expired). '
            'The call server needs the correct Agora certificate.';
      case 17:
      case 5:
        return 'The call was refused. Please try again.';
      case 2:
        return 'Invalid channel. Please try again.';
      default:
        return rawMsg.isNotEmpty ? rawMsg : 'Call error $code.';
    }
  }
}

class _AgoraCredentials {
  final String? appId;
  final String? token;
  const _AgoraCredentials({required this.appId, required this.token});
}
