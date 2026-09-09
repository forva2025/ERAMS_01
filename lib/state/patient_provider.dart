import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/incident.dart';
import '../models/trip.dart';
import '../services/patient_service.dart';
import '../services/supabase_service.dart';

// ── Patient GPS location ──────────────────────────────────────────────────────

/// Kampala city centre — used as the default when GPS is unavailable on web.
const _kampalaDefault = LatLng(0.3136, 32.5811);

final patientLocationProvider = FutureProvider<LatLng>((ref) async {
  if (kIsWeb) {
    // On web, try the browser geolocation API via geolocator
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 8));
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return _kampalaDefault;
    }
  }

  // Native (Android/iOS)
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return _kampalaDefault;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return _kampalaDefault;
  }
  if (permission == LocationPermission.deniedForever) return _kampalaDefault;

  final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return LatLng(pos.latitude, pos.longitude);
});

// ── Nearby ambulances (live) ──────────────────────────────────────────────────

/// Available ambulances near the patient, kept live. Re-fetches whenever any
/// ambulance row changes — a driver coming online, moving (GPS push), or going
/// offline — so the discovery map reflects reality in real time. A periodic
/// refresh backs up Realtime in case events don't arrive.
class NearbyAmbulancesNotifier
    extends AutoDisposeAsyncNotifier<List<Ambulance>> {
  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _poll;

  @override
  Future<List<Ambulance>> build() async {
    final location =
        ref.watch(patientLocationProvider).valueOrNull ?? _kampalaDefault;
    _subscribeRealtime();
    _poll ??= Timer.periodic(
        const Duration(seconds: 20), (_) => _scheduleRefresh());
    ref.onDispose(() {
      _debounce?.cancel();
      _poll?.cancel();
      _poll = null;
      _channel?.unsubscribe();
      _channel = null;
    });
    return PatientService()
        .fetchNearbyAmbulances(location.latitude, location.longitude);
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('patient:nearby_ambulances')
        .onPostgresChanges(
          // Any change: a driver going available, pushing a new location, or
          // going offline all affect who shows on the discovery map.
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ambulances',
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  /// Coalesce bursts of updates into a single refresh.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _refresh);
  }

  Future<void> _refresh() async {
    final location =
        ref.read(patientLocationProvider).valueOrNull ?? _kampalaDefault;
    try {
      final list = await PatientService()
          .fetchNearbyAmbulances(location.latitude, location.longitude);
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final nearbyAmbulancesProvider = AsyncNotifierProvider.autoDispose<
    NearbyAmbulancesNotifier, List<Ambulance>>(
  NearbyAmbulancesNotifier.new,
);

// ── Patient's active trip/incident ───────────────────────────────────────────

/// Returns the patient's current active incident (pending_acceptance →
/// arrived), or null when they have no active trip.
final patientActiveIncidentProvider =
    FutureProvider.autoDispose<Incident?>((ref) async {
  return PatientService().fetchActiveTrip();
});

// ── Realtime incident tracking (by incidentId) ────────────────────────────────

class ActiveIncidentNotifier
    extends FamilyAsyncNotifier<Incident?, String> {
  RealtimeChannel? _channel;
  Timer? _poll;
  late String _incidentId;

  @override
  Future<Incident?> build(String incidentId) async {
    _incidentId = incidentId;
    final data = await supabaseClient
        .from('incidents')
        .select()
        .eq('id', _incidentId)
        .maybeSingle();
    _subscribeRealtime();
    // Backs up Realtime in case the "driver accepted" (or any other status)
    // event is dropped for this client -- same rationale as
    // NearbyAmbulancesNotifier above. Self-stops once the trip reaches a
    // terminal status (see _refresh), since this provider isn't autoDispose
    // and would otherwise poll a finished incident forever.
    _poll ??=
        Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    ref.onDispose(() {
      _poll?.cancel();
      _poll = null;
      _channel?.unsubscribe();
    });
    return data != null ? Incident.fromJson(data) : null;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('patient:incident:$_incidentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _incidentId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final data = await supabaseClient
          .from('incidents')
          .select()
          .eq('id', _incidentId)
          .maybeSingle();
      final incident = data != null ? Incident.fromJson(data) : null;
      state = AsyncData(incident);
      if (incident == null || !incident.status.isActive) {
        _poll?.cancel();
        _poll = null;
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Cancels this request. Realtime subscription refreshes state once the
  /// incident row flips to 'cancelled'.
  Future<void> cancelTrip({String? reason}) async {
    await PatientService().cancelTrip(_incidentId, reason: reason);
  }
}

final activeIncidentProvider = AsyncNotifierProvider.family<
    ActiveIncidentNotifier, Incident?, String>(
  ActiveIncidentNotifier.new,
);

// ── Realtime ambulance location tracking (by ambulanceId) ─────────────────────

class TrackingAmbulanceNotifier
    extends FamilyAsyncNotifier<Ambulance?, String> {
  RealtimeChannel? _channel;
  late String _ambulanceId;

  @override
  Future<Ambulance?> build(String ambulanceId) async {
    _ambulanceId = ambulanceId;
    final data = await supabaseClient
        .from('ambulances')
        .select()
        .eq('id', _ambulanceId)
        .maybeSingle();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data != null ? Ambulance.fromJson(data) : null;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('patient:ambulance:$_ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ambulances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final data = await supabaseClient
          .from('ambulances')
          .select()
          .eq('id', _ambulanceId)
          .maybeSingle();
      state = AsyncData(data != null ? Ambulance.fromJson(data) : null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final trackingAmbulanceProvider = AsyncNotifierProvider.family<
    TrackingAmbulanceNotifier, Ambulance?, String>(
  TrackingAmbulanceNotifier.new,
);

// ── Trip + driver info (one-time fetch for tracking screen) ───────────────────

final tripWithDriverProvider = FutureProvider.family
    .autoDispose<({Trip trip, String driverName, String driverPhone})?, String>(
  (ref, incidentId) => PatientService().fetchTripWithDriver(incidentId),
);
