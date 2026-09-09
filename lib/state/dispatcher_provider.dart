import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import '../services/ambulance_service.dart';
import '../services/incident_service.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Incidents — owns the Realtime subscription for the incidents table
// ---------------------------------------------------------------------------

class IncidentsNotifier extends AsyncNotifier<List<Incident>> {
  RealtimeChannel? _channel;

  @override
  Future<List<Incident>> build() async {
    final incidents = await IncidentService().fetchActiveIncidents();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return incidents;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('dispatcher:incidents')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    // Keep existing data visible while fetching (no loading flash)
    try {
      final updated = await IncidentService().fetchActiveIncidents();
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final incidentsNotifierProvider =
    AsyncNotifierProvider<IncidentsNotifier, List<Incident>>(
  IncidentsNotifier.new,
);

// ---------------------------------------------------------------------------
// Ambulances — owns the Realtime subscription for the ambulances table
// ---------------------------------------------------------------------------

class AmbulancesNotifier extends AsyncNotifier<List<Ambulance>> {
  RealtimeChannel? _channel;

  @override
  Future<List<Ambulance>> build() async {
    final ambulances = await AmbulanceService().fetchAllAmbulances();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return ambulances;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('dispatcher:ambulances')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ambulances',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final updated = await AmbulanceService().fetchAllAmbulances();
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final ambulancesNotifierProvider =
    AsyncNotifierProvider<AmbulancesNotifier, List<Ambulance>>(
  AmbulancesNotifier.new,
);

// ---------------------------------------------------------------------------
// Hospitals — fetched once on dashboard load
// ---------------------------------------------------------------------------

final hospitalsProvider = FutureProvider<List<Hospital>>((ref) async {
  return IncidentService().fetchHospitals();
});

// ---------------------------------------------------------------------------
// UI state
// ---------------------------------------------------------------------------

/// Currently active status filter on the incident list ('all' means no filter).
final incidentFilterProvider = StateProvider<String>((ref) => 'all');

/// ID of the incident selected on the map (used to fly-to and highlight card).
final selectedIncidentIdProvider = StateProvider<String?>((ref) => null);
