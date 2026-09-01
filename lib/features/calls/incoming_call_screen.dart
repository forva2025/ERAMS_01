import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../core/theme/app_colors.dart';
import '../../models/call.dart';
import '../../models/profile.dart';
import '../../services/call_service.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../state/call_provider.dart';
import '../../widgets/call_screen.dart';

/// Full-screen incoming-call alert shown by GlobalNotificationListener from
/// anywhere in the app (via the root navigator) when incomingCallProvider
/// reports a new ringing call. Same 30s-countdown shape as the driver's
/// job-offer card, but for a call instead of a trip offer.
class IncomingCallScreen extends ConsumerStatefulWidget {
  final Call call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  static const _ringSeconds = 30;
  int _secondsLeft = _ringSeconds;
  Timer? _timer;
  bool _acting = false;
  String? _callerLabel;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _resolveCallerLabel();
    _startRinging();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _respond('missed');
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _startRinging() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/ringtone.mp3'));
    } catch (_) {
      // No ringtone asset bundled yet — silent ring, still visible/vibrating.
    }
    if (!kIsWeb) {
      try {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
        }
      } catch (_) {
        // Vibration unsupported on this device — ignore.
      }
    }
  }

  Future<void> _resolveCallerLabel() async {
    try {
      final incident = await supabaseClient
          .from('incidents')
          .select('reporter_name, assigned_ambulance_id')
          .eq('id', widget.call.incidentId)
          .maybeSingle();
      if (incident == null || !mounted) return;

      final myRole = ref.read(currentProfileProvider).valueOrNull?.role;
      if (myRole == UserRole.patient) {
        final ambulanceId = incident['assigned_ambulance_id'] as String?;
        if (ambulanceId == null) return;
        final ambulance = await supabaseClient
            .from('ambulances')
            .select('plate_number')
            .eq('id', ambulanceId)
            .maybeSingle();
        final plate = ambulance?['plate_number'] as String?;
        if (mounted && plate != null) {
          setState(() => _callerLabel = 'Ambulance $plate');
        }
      } else {
        final name = incident['reporter_name'] as String?;
        if (mounted && name != null && name.isNotEmpty) {
          setState(() => _callerLabel = name);
        }
      }
    } catch (_) {
      // Best-effort — falls back to the generic "Incoming call" label.
    }
  }

  Future<void> _respond(String status) async {
    _timer?.cancel();
    await _player.stop();
    if (!kIsWeb) unawaited(Vibration.cancel());
    ref.read(incomingCallProvider.notifier).clear();

    if (status == 'accepted') {
      if (!mounted) return;
      setState(() => _acting = true);
      try {
        await CallService().updateStatus(widget.call.id, 'accepted');
      } catch (_) {
        // Best-effort — proceed to the call screen regardless; the caller
        // side will still see the Agora join and mark itself in-call.
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen(
            incidentId: widget.call.incidentId,
            isVideo: widget.call.isVideo,
            callId: widget.call.id,
            isCaller: false,
          ),
        ),
      );
    } else {
      try {
        await CallService().updateStatus(widget.call.id, status);
      } catch (_) {
        // Best-effort — the caller's countdown/timeout still resolves this.
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    if (!kIsWeb) unawaited(Vibration.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                widget.call.isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                child: Icon(
                  widget.call.isVideo ? Icons.videocam : Icons.call,
                  size: 52,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _callerLabel ?? 'ERAMS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ringing… $_secondsLeft s',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ResponseButton(
                      icon: Icons.call_end,
                      color: AppColors.error,
                      label: 'Decline',
                      onTap: _acting ? null : () => _respond('declined'),
                    ),
                    _ResponseButton(
                      icon: Icons.call,
                      color: AppColors.statusAvailable,
                      label: 'Accept',
                      onTap: _acting ? null : () => _respond('accepted'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ResponseButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
