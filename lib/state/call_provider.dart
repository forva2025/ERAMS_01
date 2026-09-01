import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call.dart';
import '../services/supabase_service.dart';

/// The current incoming call for this user, or null. Mirrors
/// DriverIncidentNotifier's Realtime pattern (driver_provider.dart) but
/// scoped by callee_id — a call is ephemeral/live-only, so unlike
/// notificationsProvider there's no initial fetch, just a live subscription.
class IncomingCallNotifier extends AsyncNotifier<Call?> {
  RealtimeChannel? _channel;

  @override
  Future<Call?> build() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return null;

    _channel = supabaseClient
        .channel('calls:callee:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: userId,
          ),
          callback: (payload) {
            final call = Call.fromJson(payload.newRecord);
            if (call.status == CallStatus.ringing) state = AsyncData(call);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: userId,
          ),
          callback: (payload) {
            // Caller hung up (or the call otherwise resolved) before this
            // device acted on it — clear so IncomingCallScreen auto-dismisses.
            final call = Call.fromJson(payload.newRecord);
            final current = state.valueOrNull;
            if (current != null && current.id == call.id && call.status != CallStatus.ringing) {
              state = const AsyncData(null);
            }
          },
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
    return null;
  }

  /// Called locally right after this device answers/declines, so the
  /// screen dismisses immediately without waiting on the Realtime round-trip.
  void clear() => state = const AsyncData(null);
}

final incomingCallProvider =
    AsyncNotifierProvider<IncomingCallNotifier, Call?>(IncomingCallNotifier.new);
