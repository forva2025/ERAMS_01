import 'package:flutter/material.dart';

/// Web stub — all methods are no-ops. The call screen uses kIsWeb to show a
/// "use the mobile app" message instead of calling into this service.
class AgoraService {
  bool get isInitialized => false;
  bool get localJoined => false;
  int? get remoteUid => null;
  bool get isMuted => false;
  bool get isVideoEnabled => false;
  bool get isSpeakerEnabled => true;

  // ignore: use_setters_to_change_properties
  set onUserJoined(void Function(int uid)? _) {}
  // ignore: use_setters_to_change_properties
  set onUserOffline(void Function(int uid)? _) {}
  // ignore: use_setters_to_change_properties
  set onJoined(void Function()? _) {}
  // ignore: use_setters_to_change_properties
  set onError(void Function(int code, String msg)? _) {}

  Future<void> initialize({String? appId, bool withVideo = true}) async {}
  Future<void> joinChannel(String channelId, {bool withVideo = true}) async {}
  Future<void> toggleMute() async {}
  Future<void> toggleVideo() async {}
  Future<void> switchCamera() async {}
  Future<void> toggleSpeaker() async {}
  Future<void> leave() async {}
  Future<void> dispose() async {}

  Widget localVideoView() => const SizedBox.shrink();
  Widget remoteVideoView(int uid, String channelId) => const SizedBox.shrink();
}
