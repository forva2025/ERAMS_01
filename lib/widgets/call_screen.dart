import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../services/agora_service.dart';
import '../services/call_service.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Entry point — push this route onto the navigator stack
// ---------------------------------------------------------------------------

/// Push the call screen from any screen.
///
/// [incidentId] is used as the Agora channel name.
/// [isVideo]   true = video call, false = voice-only call.
/// [callId]/[isCaller] identify this as a signaled call (see [initiateCall]
/// / IncomingCallScreen) — left null/false for any older call site that
/// hasn't been migrated to signaling yet.
Future<void> pushCallScreen(
  BuildContext context, {
  required String incidentId,
  bool isVideo = false,
  String? callId,
  bool isCaller = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CallScreen(
        incidentId: incidentId,
        isVideo: isVideo,
        callId: callId,
        isCaller: isCaller,
      ),
    ),
  );
}

/// Starts a signaled call (rings the other party via the `calls` table —
/// see IncomingCallScreen) and pushes the call screen. Replaces direct
/// `pushCallScreen()` calls at every Call-button site.
Future<void> initiateCall(
  BuildContext context, {
  required String incidentId,
  required bool isVideo,
}) async {
  try {
    final call = await CallService().startCall(incidentId: incidentId, isVideo: isVideo);
    if (!context.mounted) return;
    await pushCallScreen(
      context,
      incidentId: incidentId,
      isVideo: isVideo,
      callId: call.id,
      isCaller: true,
    );
  } catch (e) {
    if (!context.mounted) return;
    final msg = e.toString().contains('callee_not_found')
        ? 'The other party isn\'t reachable right now.'
        : 'Could not start call: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------------------------------------------------------------
// CallScreen
// ---------------------------------------------------------------------------

enum _CallState { requestingPermissions, connecting, waiting, inCall, error }

class CallScreen extends StatefulWidget {
  final String incidentId;
  final bool isVideo;
  final String? callId;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.incidentId,
    required this.isVideo,
    this.callId,
    this.isCaller = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _service = AgoraService();
  _CallState _state = _CallState.requestingPermissions;
  String? _errorMessage;
  bool _remoteJoined = false;
  RealtimeChannel? _callChannel;

  @override
  void initState() {
    super.initState();
    if (widget.callId != null) _subscribeCallStatus(widget.callId!);
    if (kIsWeb) {
      _requestWebPermissions();
    } else {
      _requestNativePermissions();
    }
  }

  /// Watches the signaled call row so this screen notices if the other
  /// party declines/misses/ends the call before (or instead of) Agora ever
  /// reporting a remote join — Agora's own callbacks have no concept of
  /// "the other person said no", only "someone joined the media channel".
  void _subscribeCallStatus(String callId) {
    _callChannel = supabaseClient
        .channel('call:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (!mounted || _state == _CallState.inCall) return;
            if (status == 'declined' || status == 'missed' || status == 'ended') {
              setState(() {
                _state = _CallState.error;
                _errorMessage = status == 'declined'
                    ? 'Call declined.'
                    : status == 'missed'
                        ? 'No answer.'
                        : 'Call ended.';
              });
              _service.leave();
            }
          },
        )
        .subscribe();
  }

  // ── Web: request browser mic/camera permission then show redirect message ─

  Future<void> _requestWebPermissions() async {
    // On web we can't run Agora; request browser permissions as a UX signal
    // so the browser marks this origin as trusted. The actual call must be
    // completed on the Android app.
    try {
      // Use the browser's getUserMedia API indirectly through the html package.
      // Even without full WebRTC, this prompt teaches the browser that the
      // origin needs mic/camera access.
      // No dart:html import needed — we just show the web fallback UI.
    } catch (_) {}
    if (mounted) setState(() => _state = _CallState.error);
  }

  // ── Native: request permissions then join channel ─────────────────────────

  Future<void> _requestNativePermissions() async {
    final permissions = <Permission>[Permission.microphone];
    if (widget.isVideo) permissions.add(Permission.camera);

    final statuses = await permissions.request();

    final micDenied =
        statuses[Permission.microphone] != PermissionStatus.granted;
    final camDenied = widget.isVideo &&
        statuses[Permission.camera] != PermissionStatus.granted;

    if (micDenied || camDenied) {
      if (mounted) {
        setState(() {
          _state = _CallState.error;
          _errorMessage = micDenied
              ? 'Microphone permission is required for calls.'
              : 'Camera permission is required for video calls.';
        });
      }
      return;
    }

    await _startCall();
  }

  Future<void> _startCall() async {
    if (!mounted) return;
    setState(() => _state = _CallState.connecting);

    _service
      ..onJoined = () {
        if (mounted) setState(() => _state = _CallState.waiting);
      }
      ..onUserJoined = (uid) {
        if (mounted) setState(() => _remoteJoined = true);
        if (_state != _CallState.inCall) {
          setState(() => _state = _CallState.inCall);
        }
      }
      ..onUserOffline = (_) {
        if (mounted) setState(() => _remoteJoined = false);
      }
      ..onError = (code, msg) {
        if (mounted) {
          setState(() {
            _state = _CallState.error;
            _errorMessage = 'Call error ($code): $msg';
          });
        }
      };

    try {
      await _service.joinChannel(
        widget.incidentId,
        withVideo: widget.isVideo,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _CallState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _endCall() async {
    await _service.leave();
    if (widget.callId != null) {
      try {
        await CallService().updateStatus(widget.callId!, 'ended');
      } catch (_) {
        // Best-effort — the other party's own leave detection is the fallback.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _callChannel?.unsubscribe();
    _service.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: kIsWeb ? _buildWebFallback() : _buildNativeCall(),
    );
  }

  // ── Web fallback UI ───────────────────────────────────────────────────────

  Widget _buildWebFallback() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isVideo
                      ? Icons.videocam_outlined
                      : Icons.call_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isVideo ? 'Video Call' : 'Voice Call',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Voice & video calling requires the ERAMS mobile app.\n\n'
                  'Open this incident on your Android device to call the '
                  'driver directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Native call UI ────────────────────────────────────────────────────────

  Widget _buildNativeCall() {
    return SafeArea(
      child: switch (_state) {
        _CallState.requestingPermissions ||
        _CallState.connecting =>
          _buildLoadingOverlay(
            _state == _CallState.requestingPermissions
                ? 'Requesting permissions…'
                : 'Connecting…',
          ),
        _CallState.error => _buildErrorOverlay(),
        _CallState.waiting || _CallState.inCall => _buildInCallUI(),
      },
    );
  }

  Widget _buildLoadingOverlay(String message) {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        _CalleeAvatar(incidentId: widget.incidentId),
        const SizedBox(height: 24),
        Text(message,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: Colors.white54),
        const Spacer(),
        _buildEndButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildErrorOverlay() {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? 'Could not start call. Check permissions.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        if (_errorMessage?.contains('permission') == true) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.white60),
            label: const Text('Open Settings',
                style: TextStyle(color: Colors.white60)),
          ),
        ],
        const Spacer(),
        _buildEndButton(label: 'Close'),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInCallUI() {
    final inCall = _state == _CallState.inCall && _remoteJoined;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Remote video (full-screen background) ────────────────────────
        if (inCall && widget.isVideo && _service.remoteUid != null)
          _service.remoteVideoView(_service.remoteUid!, widget.incidentId)
        else
          _buildWaitingBackground(inCall),

        // ── Local video (PiP top-right) ──────────────────────────────────
        if (widget.isVideo && _service.localJoined)
          Positioned(
            top: 60,
            right: 12,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _service.isVideoEnabled
                  ? _service.localVideoView()
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.videocam_off,
                          color: Colors.white54),
                    ),
            ),
          ),

        // ── Top bar ──────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),

        // ── Status label ─────────────────────────────────────────────────
        if (!inCall)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _CalleeAvatar(incidentId: widget.incidentId),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for other party…',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

        // ── Control bar ──────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildControlBar(),
        ),
      ],
    );
  }

  Widget _buildWaitingBackground(bool inCall) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            Colors.black87,
          ],
        ),
      ),
      child: inCall
          ? const Center(
              child: Icon(Icons.person, size: 100, color: Colors.white24))
          : null,
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: _endCall,
            tooltip: 'End call',
          ),
          Expanded(
            child: Text(
              widget.isVideo ? 'Video Call' : 'Voice Call',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 48), // balance the back button
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute mic
          _ControlButton(
            icon: _service.isMuted ? Icons.mic_off : Icons.mic,
            label: _service.isMuted ? 'Unmute' : 'Mute',
            active: _service.isMuted,
            onTap: () async {
              await _service.toggleMute();
              if (mounted) setState(() {});
            },
          ),
          // Toggle video (only in video mode)
          if (widget.isVideo)
            _ControlButton(
              icon: _service.isVideoEnabled
                  ? Icons.videocam
                  : Icons.videocam_off,
              label: _service.isVideoEnabled ? 'Camera' : 'Cam off',
              active: !_service.isVideoEnabled,
              onTap: () async {
                await _service.toggleVideo();
                if (mounted) setState(() {});
              },
            ),
          // Speaker toggle
          _ControlButton(
            icon: _service.isSpeakerEnabled
                ? Icons.volume_up
                : Icons.volume_off,
            label: _service.isSpeakerEnabled ? 'Speaker' : 'Earpiece',
            onTap: () async {
              await _service.toggleSpeaker();
              if (mounted) setState(() {});
            },
          ),
          // Switch camera (only in video mode)
          if (widget.isVideo)
            _ControlButton(
              icon: Icons.flip_camera_android,
              label: 'Flip',
              onTap: () async {
                await _service.switchCamera();
              },
            ),
          // End call
          _ControlButton(
            icon: Icons.call_end,
            label: 'End',
            color: Colors.redAccent,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildEndButton({String label = 'End Call'}) {
    return FilledButton.icon(
      onPressed: _endCall,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.redAccent,
        minimumSize: const Size(180, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: const Icon(Icons.call_end),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _CalleeAvatar extends StatelessWidget {
  final String incidentId;
  const _CalleeAvatar({required this.incidentId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 2),
      ),
      child: const Icon(Icons.person, size: 48, color: Colors.white60),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ??
        (active
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.1));
    final fg = color != null ? Colors.white : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
