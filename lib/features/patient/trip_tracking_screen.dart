import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/incident.dart';
import '../../models/trip.dart';
import '../../services/routing_service.dart';
import '../../state/message_provider.dart';
import '../../state/patient_provider.dart';
import '../../state/routing_provider.dart';
import '../../widgets/call_screen.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/error_state.dart';

class TripTrackingScreen extends ConsumerStatefulWidget {
  final String incidentId;
  const TripTrackingScreen({super.key, required this.incidentId});

  @override
  ConsumerState<TripTrackingScreen> createState() =>
      _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen> {
  final _mapController = MapController();
  bool _completionShown = false;
  bool _cancelShown = false;

  @override
  Widget build(BuildContext context) {
    // ── Status change listener ───────────────────────────────────────────────
    ref.listen(activeIncidentProvider(widget.incidentId), (prev, next) {
      final prevStatus = prev?.valueOrNull?.status;
      final nextStatus = next.valueOrNull?.status;

      // When driver accepts, refresh trip details to populate driver name/phone
      if (prevStatus == IncidentStatus.pendingAcceptance &&
          nextStatus == IncidentStatus.dispatched) {
        ref.invalidate(tripWithDriverProvider(widget.incidentId));
      }

      if (nextStatus == IncidentStatus.completed && !_completionShown) {
        _completionShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCompletionDialog(next.valueOrNull!);
        });
      }

      if (nextStatus == IncidentStatus.cancelled && !_cancelShown) {
        _cancelShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This trip was cancelled.')),
          );
          context.go('/patient');
        });
      }
    });

    // ── Data ─────────────────────────────────────────────────────────────────
    final incidentAsync =
        ref.watch(activeIncidentProvider(widget.incidentId));
    final incident = incidentAsync.valueOrNull;

    final ambulanceId = incident?.assignedAmbulanceId;
    final ambulanceAsync = ambulanceId != null
        ? ref.watch(trackingAmbulanceProvider(ambulanceId))
        : const AsyncData<Ambulance?>(null);
    final ambulance = ambulanceAsync.valueOrNull;

    final tripAsync =
        ref.watch(tripWithDriverProvider(widget.incidentId));

    // Patient location comes from the incident record (where they requested)
    final patLat = incident?.latitude;
    final patLng = incident?.longitude;
    final patientLatLng = (patLat != null && patLng != null)
        ? LatLng(patLat, patLng)
        : const LatLng(0.3136, 32.5811);

    final ambulanceLatLng =
        (ambulance?.latitude != null && ambulance?.longitude != null)
            ? LatLng(ambulance!.latitude!, ambulance.longitude!)
            : null;

    // Shortest road route the ambulance will actually drive to reach the
    // patient. Falls back to a straight-line haversine estimate below while
    // it's loading or if the routing server can't be reached.
    final routeAsync = ambulanceLatLng != null
        ? ref.watch(
            routeProvider(routeCacheKey(ambulanceLatLng, patientLatLng)))
        : const AsyncData<RouteResult?>(null);
    final route = routeAsync.valueOrNull;

    final etaMin =
        route?.durationMin ?? _etaMinutes(ambulanceLatLng, patientLatLng);
    final distKm =
        route?.distanceKm ?? _distanceKm(ambulanceLatLng, patientLatLng);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          incident?.natureOfEmergency ?? 'Live Tracking',
          overflow: TextOverflow.ellipsis,
        ),
        leading: BackButton(onPressed: () => context.go('/patient')),
        actions: [
          if (incident != null && _isCancellable(incident.status))
            IconButton(
              tooltip: 'Cancel request',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _confirmCancel(),
            ),
        ],
      ),
      body: incidentAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () =>
              ref.invalidate(activeIncidentProvider(widget.incidentId)),
        ),
        data: (incident) {
          if (incident == null) {
            return const Center(
              child: Text('Trip not found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return Stack(
            children: [
              // ── Full-screen map ─────────────────────────────────────────
              _buildMap(
                patientLatLng: patientLatLng,
                ambulanceLatLng: ambulanceLatLng,
                route: route,
              ),

              // ── OSM attribution ─────────────────────────────────────────
              const Positioned(
                bottom: 200,
                right: 8,
                child: Text(
                  '© OpenStreetMap contributors',
                  style:
                      TextStyle(fontSize: 9, color: Color(0x80000000)),
                ),
              ),

              // ── Status banner ────────────────────────────────────────────
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: _StatusBanner(status: incident.status),
              ),

              // ── Video call FAB ────────────────────────────────────────────
              if (incident.status == IncidentStatus.dispatched ||
                  incident.status == IncidentStatus.enRoute ||
                  incident.status == IncidentStatus.arrived)
                Positioned(
                  bottom: 372,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'video_call_tracking',
                    tooltip: 'Video Call',
                    backgroundColor: AppColors.statusEnRoute,
                    foregroundColor: Colors.white,
                    onPressed: () => initiateCall(
                      context,
                      incidentId: widget.incidentId,
                      isVideo: true,
                    ),
                    child: const Icon(Icons.videocam_outlined),
                  ),
                ),

              // ── Voice call FAB ────────────────────────────────────────────
              if (incident.status == IncidentStatus.dispatched ||
                  incident.status == IncidentStatus.enRoute ||
                  incident.status == IncidentStatus.arrived)
                Positioned(
                  bottom: 318,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'voice_call_tracking',
                    tooltip: 'Voice Call',
                    backgroundColor: AppColors.statusAvailable,
                    foregroundColor: Colors.white,
                    onPressed: () => initiateCall(
                      context,
                      incidentId: widget.incidentId,
                      isVideo: false,
                    ),
                    child: const Icon(Icons.call_outlined),
                  ),
                ),

              // ── Chat FAB ─────────────────────────────────────────────────
              Positioned(
                bottom: 264,
                right: 16,
                child: Builder(
                  builder: (ctx) {
                    final msgs = ref.watch(
                        messagesProvider(widget.incidentId));
                    final seen = ref.watch(
                        chatSeenProvider)[widget.incidentId] ?? 0;
                    final unread = ((msgs.valueOrNull?.length ?? 0) -
                            seen)
                        .clamp(0, 99);
                    return FloatingActionButton.small(
                      heroTag: 'chat_tracking',
                      tooltip: 'Chat',
                      onPressed: () => showChatSheet(
                          context, widget.incidentId),
                      child: chatIconWithBadge(unread),
                    );
                  },
                ),
              ),

              // ── Re-center FAB ─────────────────────────────────────────────
              Positioned(
                bottom: 210,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'recenter_tracking',
                  tooltip: 'Centre on ambulance',
                  onPressed: () {
                    final target = ambulanceLatLng ?? patientLatLng;
                    _mapController.move(target, 15);
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // ── Bottom trip info card ─────────────────────────────────────
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _TripInfoCard(
                  ambulance: ambulance,
                  tripAsync: tripAsync,
                  etaMin: etaMin,
                  distanceKm: distKm,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap({
    required LatLng patientLatLng,
    required LatLng? ambulanceLatLng,
    required RouteResult? route,
  }) {
    final center = ambulanceLatLng != null
        ? LatLng(
            (patientLatLng.latitude + ambulanceLatLng.latitude) / 2,
            (patientLatLng.longitude + ambulanceLatLng.longitude) / 2,
          )
        : patientLatLng;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.erams.erams',
        ),
        if (ambulanceLatLng != null)
          if (route != null)
            // Highlighted shortest road route the ambulance will follow
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route.points,
                  color: AppColors.primary,
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
              ],
            )
          else
            // Fallback: straight dashed line while the route is loading or
            // the routing server is unreachable
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [ambulanceLatLng, patientLatLng],
                  color: AppColors.primary.withValues(alpha: 0.45),
                  strokeWidth: 2.5,
                  isDotted: true,
                ),
              ],
            ),
        // Patient marker
        MarkerLayer(
          markers: [
            Marker(
              point: patientLatLng,
              width: 48,
              height: 48,
              child: const _PatientMarker(),
            ),
          ],
        ),
        // Ambulance marker
        if (ambulanceLatLng != null)
          MarkerLayer(
            markers: [
              Marker(
                point: ambulanceLatLng,
                width: 48,
                height: 48,
                child: const _AmbulanceMarker(),
              ),
            ],
          ),
      ],
    );
  }

  // ── Geometry helpers ────────────────────────────────────────────────────────

  double? _etaMinutes(LatLng? ambulance, LatLng patient) {
    if (ambulance == null) return null;
    final dist = _haversineKm(ambulance.latitude, ambulance.longitude,
        patient.latitude, patient.longitude);
    return dist / 35.0 * 60; // 35 km/h average in Kampala
  }

  double? _distanceKm(LatLng? ambulance, LatLng patient) {
    if (ambulance == null) return null;
    return _haversineKm(ambulance.latitude, ambulance.longitude,
        patient.latitude, patient.longitude);
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  // ── Completion dialog ───────────────────────────────────────────────────────

  void _showCompletionDialog(Incident incident) {
    final tripData = ref.read(tripWithDriverProvider(widget.incidentId));
    final record = tripData.valueOrNull;
    final trip = record?.trip;
    final driverName = record?.driverName ?? '';

    final ambulancePlate = trip?.ambulanceId != null
        ? ref
                .read(trackingAmbulanceProvider(trip!.ambulanceId!))
                .valueOrNull
                ?.plateNumber ??
            ''
        : '';

    Duration? duration;
    if (trip != null) {
      final end = trip.completedAt ?? DateTime.now().toUtc();
      duration = end.difference(trip.requestedAt);
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.statusAvailable, size: 60),
            SizedBox(height: 12),
            Text(
              'Trip Completed!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (duration != null)
              _SummaryRow(
                Icons.timer_outlined,
                'Duration',
                _formatDuration(duration),
              ),
            if (trip?.totalFare != null) ...[
              const SizedBox(height: 10),
              _SummaryRow(
                Icons.receipt_long_outlined,
                'Total Fare',
                'UGX ${trip!.totalFare!.toStringAsFixed(0)}',
              ),
            ],
            const SizedBox(height: 10),
            _SummaryRow(
              Icons.payment_outlined,
              'Payment',
              _paymentLabel(trip?.paymentMethod ?? 'cash'),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.invalidate(patientActiveIncidentProvider);
                    context.go('/patient');
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.invalidate(patientActiveIncidentProvider);
                    context.go('/patient/rating', extra: {
                      'tripId': trip?.id ?? '',
                      'ambulancePlate': ambulancePlate,
                      'driverName': driverName,
                    });
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Rate Experience',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isCancellable(IncidentStatus status) =>
      status != IncidentStatus.completed &&
      status != IncidentStatus.cancelled;

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel this request?'),
        content: const Text(
            'The assigned ambulance will be freed up for other emergencies. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(activeIncidentProvider(widget.incidentId).notifier)
          .cancelTrip();
      // The ref.listen block above shows the snackbar and navigates back
      // once Realtime confirms the incident is 'cancelled'.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours} hr ${d.inMinutes.remainder(60)} min';
  }

  static String _paymentLabel(String method) => switch (method) {
        'mtn_momo' => 'MTN MoMo',
        'airtel_money' => 'Airtel Money',
        _ => 'Cash',
      };
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final IncidentStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, message) = switch (status) {
      IncidentStatus.pendingAcceptance => (
          AppColors.statusPending,
          Icons.access_time_rounded,
          'Waiting for driver to accept…',
        ),
      IncidentStatus.dispatched => (
          AppColors.statusDispatched,
          Icons.airport_shuttle_outlined,
          'Driver accepted — on the way!',
        ),
      IncidentStatus.enRoute => (
          AppColors.statusEnRoute,
          Icons.directions_car_outlined,
          'En route to destination',
        ),
      IncidentStatus.arrived => (
          AppColors.statusArrived,
          Icons.location_on_outlined,
          'Ambulance has arrived',
        ),
      IncidentStatus.completed => (
          AppColors.statusCompleted,
          Icons.check_circle_outline,
          'Trip completed',
        ),
      _ => (
          AppColors.textSecondary,
          Icons.info_outline,
          status.label,
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip info card ────────────────────────────────────────────────────────────

class _TripInfoCard extends StatelessWidget {
  final Ambulance? ambulance;
  final AsyncValue<({Trip trip, String driverName, String driverPhone})?>
      tripAsync;
  final double? etaMin;
  final double? distanceKm;

  const _TripInfoCard({
    required this.ambulance,
    required this.tripAsync,
    required this.etaMin,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ambulance row
            Row(
              children: [
                const Icon(Icons.airport_shuttle,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  ambulance?.plateNumber ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(width: 8),
                if (ambulance != null)
                  _Tag(ambulance!.serviceType.shortLabel,
                      AppColors.primary),
                const Spacer(),
                if (etaMin != null) ...[
                  const Icon(Icons.timer_outlined,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatEta(etaMin!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
            if (distanceKm != null) ...[
              const SizedBox(height: 3),
              Text(
                '${_formatDist(distanceKm!)} away',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const Divider(height: 18),
            // Driver + fare
            tripAsync.when(
              loading: () =>
                  const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                return _TripDetails(data: data);
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatEta(double min) {
    if (min < 1) return '< 1 min';
    if (min < 60) return '${min.round()} min';
    final h = min ~/ 60;
    final m = min.round() % 60;
    return '${h}h ${m}m';
  }

  static String _formatDist(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}

class _TripDetails extends StatelessWidget {
  final ({Trip trip, String driverName, String driverPhone}) data;
  const _TripDetails({required this.data});

  @override
  Widget build(BuildContext context) {
    final driverName = data.driverName;
    final driverPhone = data.driverPhone;
    final trip = data.trip;

    return Column(
      children: [
        // Driver row
        Row(
          children: [
            const Icon(Icons.person_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                driverName.isEmpty
                    ? 'Awaiting driver assignment…'
                    : driverName,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            if (driverPhone.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:$driverPhone');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.statusAvailable
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.statusAvailable
                            .withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone,
                          size: 13, color: AppColors.statusAvailable),
                      SizedBox(width: 4),
                      Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.statusAvailable,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Fare row
        Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              trip.totalFare != null
                  ? 'UGX ${trip.totalFare!.toStringAsFixed(0)}'
                  : 'Fare: calculating…',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            _Tag(_paymentLabel(trip.paymentMethod), Colors.blueGrey),
          ],
        ),
      ],
    );
  }

  static String _paymentLabel(String m) => switch (m) {
        'mtn_momo' => 'MTN MoMo',
        'airtel_money' => 'Airtel Money',
        _ => 'Cash',
      };
}

// ── Map markers ───────────────────────────────────────────────────────────────

class _PatientMarker extends StatelessWidget {
  const _PatientMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: const Icon(Icons.person_pin_circle,
          color: Colors.blue, size: 20),
    );
  }
}

class _AmbulanceMarker extends StatelessWidget {
  const _AmbulanceMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.airport_shuttle,
          color: Colors.white, size: 22),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
