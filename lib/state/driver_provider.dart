import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import '../services/driver_service.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Driver's ambulance — Realtime subscription on their specific row
// ---------------------------------------------------------------------------

class DriverAmbulanceNotifier extends AsyncNotifier<Ambulance?> {
  RealtimeChannel? _channel;

  @override
  Future<Ambulance?> build() async {
    final ambulance = await DriverService().fetchMyAmbulance();
    if (ambulance != null) _subscribeRealtime(ambulance.id);
    ref.onDispose(() => _channel?.unsubscribe());
    return ambulance;
  }

  void _subscribeRealtime(String ambulanceId) {
    _channel = supabaseClient
        .channel('driver:ambulance:$ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ambulances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      state = AsyncData(await DriverService().fetchMyAmbulance());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> setStatus(String status) async {
    final amb = state.valueOrNull;
    if (amb == null) return;
    await DriverService().setAmbulanceStatus(amb.id, status);
    // Optimistic update; Realtime confirms shortly after
    state = AsyncData(amb.copyWith(status: AmbulanceStatus.fromString(status)));
  }
}

final driverAmbulanceProvider =
    AsyncNotifierProvider<DriverAmbulanceNotifier, Ambulance?>(
  DriverAmbulanceNotifier.new,
);

// ---------------------------------------------------------------------------
// Active incident for this driver — filtered Realtime subscription
// ---------------------------------------------------------------------------

class DriverIncidentNotifier extends AsyncNotifier<Incident?> {
  RealtimeChannel? _channel;
  // The ambulance ID this build's fetch/Realtime subscription is keyed to.
  // Used only to detect a genuine reassignment to a different ambulance.
  String? _subscribedAmbulanceId;

  @override
  Future<Incident?> build() async {
    // ref.read (not ref.watch): only need the ambulance ID once per build.
    // Watching `.future` made Riverpod fully re-run this build() (briefly
    // showing `loading`, wiping the active-incident card) every ~15s --
    // every GPS location push updates the driver's own `ambulances` row,
    // which unconditionally re-notifies `.future` watchers regardless of
    // whether anything relevant to this notifier actually changed.
    final ambulance = await ref.read(driverAmbulanceProvider.future);

    // Still notice a genuine reassignment to a different ambulance (e.g. an
    // admin moves this driver to another vehicle) -- just not every routine
    // field update (GPS, status) on the same one.
    ref.listen<AsyncValue<Ambulance?>>(driverAmbulanceProvider, (prev, next) {
      if (next.valueOrNull?.id != _subscribedAmbulanceId) {
        ref.invalidateSelf();
      }
    });

    if (ambulance == null) {
      _subscribedAmbulanceId = null;
      return null;
    }

    _subscribedAmbulanceId = ambulance.id;
    final incident =
        await DriverService().fetchActiveIncident(ambulance.id);
    _subscribeRealtime(ambulance.id);
    ref.onDispose(() => _channel?.unsubscribe());
    return incident;
  }

  void _subscribeRealtime(String ambulanceId) {
    _channel = supabaseClient
        .channel('driver:incidents:$ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_ambulance_id',
            value: ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final ambulance = ref.read(driverAmbulanceProvider).valueOrNull;
      if (ambulance == null) {
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(
          await DriverService().fetchActiveIncident(ambulance.id));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Re-fetches the current offer/incident after a failed accept/decline.
  /// The RPCs reject with `unauthorized`/`invalid_status` when the offer has
  /// already moved on server-side (taken, expired, or reassigned to a
  /// different ambulance) — refreshing here lets the job-offer dialog
  /// notice `stillOffered` is now false and close itself, instead of
  /// leaving the driver stuck retapping Accept against a dead offer.
  Future<void> refreshAfterConflict() => _refresh();

  Future<void> acceptOffer() async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    await DriverService().acceptTrip(incident.id);
    // Realtime should also push this update, but don't leave the driver
    // stuck on the job-offer screen if that's delayed or dropped — refresh
    // now so the active-incident card (and call/chat buttons) appear
    // immediately, same as declineOffer() below.
    await _refresh();
  }

  /// Declines the current job offer. After decline, the incident is
  /// re-assigned to a different ambulance, so the Realtime filter on this
  /// ambulance_id will no longer fire — we must refresh manually.
  Future<void> declineOffer({String? reasonCategory, String? reasonNotes}) async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    await DriverService().declineTrip(
      incident.id,
      reasonCategory: reasonCategory,
      reasonNotes: reasonNotes,
    );
    await _refresh();
  }

  Future<void> advanceStatus() async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    final next = switch (incident.status) {
      IncidentStatus.dispatched => 'en_route',
      IncidentStatus.enRoute => 'arrived',
      IncidentStatus.arrived => 'completed',
      _ => null,
    };
    if (next == null) return;
    await DriverService().updateIncidentStatus(incident.id, next);
    // Same reasoning as acceptOffer(): don't rely solely on Realtime to
    // reflect the driver's own action back to them.
    await _refresh();
  }
}

final driverIncidentProvider =
    AsyncNotifierProvider<DriverIncidentNotifier, Incident?>(
  DriverIncidentNotifier.new,
);

// ---------------------------------------------------------------------------
// Hospital lookup — family provider, cached by hospital ID
// ---------------------------------------------------------------------------

final hospitalByIdProvider =
    FutureProvider.family<Hospital?, String>((ref, id) {
  return DriverService().fetchHospital(id);
});

// ---------------------------------------------------------------------------
// GPS tracking — streams the device position and uploads it every 15 s.
// Works on web (via geolocator_web / the browser Geolocation API) as well as
// Android/iOS/desktop.
// ---------------------------------------------------------------------------

/// Whether the device position is currently being streamed and shared.
final gpsActiveProvider = StateProvider<bool>((ref) => false);

/// Outcome of a [GpsNotifier.startTracking] attempt, so the UI can explain to
/// the driver exactly why location sharing did or didn't begin.
enum GpsStartResult {
  started,
  alreadyRunning,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class GpsNotifier extends AsyncNotifier<Position?> {
  StreamSubscription<Position>? _positionSub;
  Timer? _uploadTimer;
  Position? _latestPosition;
  final _queue = <({String ambulanceId, double lat, double lng})>[];

  @override
  Future<Position?> build() async {
    ref.onDispose(() {
      _positionSub?.cancel();
      _uploadTimer?.cancel();
    });
    return null;
  }

  Future<GpsStartResult> startTracking() async {
    // Already streaming — treat as success, don't open a second stream.
    if (_positionSub != null) return GpsStartResult.alreadyRunning;

    // Location services must be enabled on the device / browser.
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      // Some browsers throw instead of answering — assume available and let
      // the permission check below be the real gate.
      serviceEnabled = true;
    }
    if (!serviceEnabled) return GpsStartResult.serviceDisabled;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return GpsStartResult.permissionDeniedForever;
    }
    if (perm != LocationPermission.whileInUse &&
        perm != LocationPermission.always) {
      return GpsStartResult.permissionDenied;
    }

    ref.read(gpsActiveProvider.notifier).state = true;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        final isFirstFix = _latestPosition == null;
        _latestPosition = pos;
        state = AsyncData(pos);
        // Publish the very first fix immediately so the driver appears on the
        // map without waiting for the next upload tick.
        if (isFirstFix) _pushLocation();
      },
      onError: (Object e, StackTrace st) {
        // Stream failed mid-session (permission revoked, hardware error) —
        // flip back to inactive so the badge reflects reality.
        state = AsyncError(e, st);
        stopTracking();
      },
      cancelOnError: true,
    );

    // Upload on a fixed 15-second cadence regardless of stream frequency.
    _uploadTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());

    return GpsStartResult.started;
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _latestPosition = null;
    ref.read(gpsActiveProvider.notifier).state = false;
  }

  Future<void> _pushLocation() async {
    final pos = _latestPosition;
    if (pos == null) return;
    final amb = ref.read(driverAmbulanceProvider).valueOrNull;
    if (amb == null) return;

    try {
      if (_queue.isNotEmpty) {
        final pending = List.of(_queue);
        _queue.clear();
        for (final p in pending) {
          await DriverService().pushLocation(p.ambulanceId, p.lat, p.lng);
        }
      }
      await DriverService().pushLocation(amb.id, pos.latitude, pos.longitude);
    } catch (_) {
      // Queue for retry on next tick
      _queue.add((
        ambulanceId: amb.id,
        lat: pos.latitude,
        lng: pos.longitude,
      ));
    }
  }
}

final gpsNotifierProvider =
    AsyncNotifierProvider<GpsNotifier, Position?>(GpsNotifier.new);
