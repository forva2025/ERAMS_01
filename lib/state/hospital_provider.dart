import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import '../services/hospital_service.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Hospital entity for the current user
// ---------------------------------------------------------------------------

final myHospitalProvider = FutureProvider<Hospital?>((ref) {
  return HospitalService().fetchMyHospital();
});

// ---------------------------------------------------------------------------
// Incidents assigned to this hospital — Realtime subscription
// ---------------------------------------------------------------------------

class HospitalIncidentsNotifier extends AsyncNotifier<List<Incident>> {
  RealtimeChannel? _channel;
  String? _hospitalId;

  @override
  Future<List<Incident>> build() async {
    final hospital = await ref.watch(myHospitalProvider.future);
    if (hospital == null) return [];
    _hospitalId = hospital.id;
    final incidents =
        await HospitalService().fetchAssignedIncidents(hospital.id);
    _subscribeRealtime(hospital.id);
    ref.onDispose(() => _channel?.unsubscribe());
    return incidents;
  }

  void _subscribeRealtime(String hospitalId) {
    _channel = supabaseClient
        .channel('hospital:incidents:$hospitalId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_hospital_id',
            value: hospitalId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    final hid = _hospitalId;
    if (hid == null) return;
    try {
      state =
          AsyncData(await HospitalService().fetchAssignedIncidents(hid));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final hospitalIncidentsProvider =
    AsyncNotifierProvider<HospitalIncidentsNotifier, List<Incident>>(
  HospitalIncidentsNotifier.new,
);

// ---------------------------------------------------------------------------
// All ambulances with live location — refreshes on Realtime ambulance updates
// ---------------------------------------------------------------------------

class HospitalAmbulancesNotifier extends AsyncNotifier<List<Ambulance>> {
  RealtimeChannel? _channel;

  @override
  Future<List<Ambulance>> build() async {
    final ambulances = await HospitalService().fetchAllAmbulances();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return ambulances;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('hospital:ambulances')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ambulances',
          callback: (_) async {
            try {
              state = AsyncData(
                  await HospitalService().fetchAllAmbulances());
            } catch (e, st) {
              state = AsyncError(e, st);
            }
          },
        )
        .subscribe();
  }
}

final hospitalAmbulancesProvider =
    AsyncNotifierProvider<HospitalAmbulancesNotifier, List<Ambulance>>(
  HospitalAmbulancesNotifier.new,
);

// ---------------------------------------------------------------------------
// Acknowledged incidents — loaded from DB, so survives page refresh
// ---------------------------------------------------------------------------

class AcknowledgedIncidentsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    // Re-run whenever the incidents list changes so new incidents get checked
    final incidents = await ref.watch(hospitalIncidentsProvider.future);
    final ids = incidents.map((i) => i.id).toList();
    return HospitalService().fetchAcknowledgedIncidentIds(ids);
  }

  /// Optimistically marks [incidentId] as acknowledged without waiting for
  /// the next full rebuild.
  void markAcknowledged(String incidentId) {
    final current = state.valueOrNull ?? {};
    state = AsyncData({...current, incidentId});
  }
}

final acknowledgedIncidentsProvider =
    AsyncNotifierProvider<AcknowledgedIncidentsNotifier, Set<String>>(
  AcknowledgedIncidentsNotifier.new,
);
