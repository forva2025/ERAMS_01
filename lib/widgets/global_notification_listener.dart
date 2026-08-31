import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calls/incoming_call_screen.dart';
import '../state/call_provider.dart';
import '../state/notification_provider.dart';

/// Wraps the whole app (via MaterialApp.router's `builder:`) so an in-app
/// banner or an incoming-call screen can appear regardless of which screen
/// is currently open — mirrors the per-screen job-offer dialog pattern in
/// driver_screen.dart, but at the app root since either can land on any
/// role's screen.
class GlobalNotificationListener extends ConsumerWidget {
  final Widget? child;

  const GlobalNotificationListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationsProvider, (previous, next) {
      // Skip the initial load (previous == null) — only banner genuinely
      // new arrivals, not the existing history fetched on first build.
      if (previous == null) return;
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      final latest = list.first;
      final prevLatestId = previous.valueOrNull?.firstOrNull?.id;
      if (latest.id == prevLatestId) return;

      final messenger = rootScaffoldMessengerKey.currentState;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('${latest.title} — ${latest.body}'),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    ref.listen(incomingCallProvider, (previous, next) {
      final call = next.valueOrNull;
      if (call == null) return;
      if (previous?.valueOrNull?.id == call.id) return;

      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(call: call),
        ),
      );
    });

    return child ?? const SizedBox.shrink();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Set by app.dart's MaterialApp.router — lets this widget show a SnackBar
/// without a BuildContext that's guaranteed to be under a Scaffold (the
/// `builder:` callback runs above the routed page, not inside it).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Also set on MaterialApp.router — lets app-root listeners push a screen
/// (e.g. an incoming-call screen) from outside any specific route's
/// BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();
