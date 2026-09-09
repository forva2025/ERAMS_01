import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/incident.dart';
import '../../services/auth_service.dart';
import '../../state/patient_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/chat_list_view.dart';
import '../../widgets/profile_edit_sheet.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  final _mapController = MapController();
  Ambulance? _selectedAmbulance;

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(patientLocationProvider);
    final ambulancesAsync = ref.watch(nearbyAmbulancesProvider);
    final activeTripAsync = ref.watch(patientActiveIncidentProvider);
    final activeTrip = activeTripAsync.valueOrNull;
    final hasActiveTrip = activeTrip != null;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogoHorizontal(),
        actions: [
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => showChatListSheet(context),
          ),
          IconButton(
            tooltip: 'My profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => showProfileSheet(context),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          locationAsync.when(
            loading: () => const ColoredBox(
              color: Color(0xFFEEF1F4),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _buildMap(
                const LatLng(0.3136, 32.5811), ambulancesAsync.valueOrNull ?? []),
            data: (location) =>
                _buildMap(location, ambulancesAsync.valueOrNull ?? []),
          ),

          // ── OSM attribution ───────────────────────────────────────────────
          const Positioned(
            bottom: 160,
            right: 8,
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Color(0x80000000)),
            ),
          ),

          // ── Available count chip ──────────────────────────────────────────
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: ambulancesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (ambulances) => _CountChip(count: ambulances.length),
              ),
            ),
          ),

          // ── Selected ambulance info card ──────────────────────────────────
          if (_selectedAmbulance != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _AmbulanceInfoCard(
                ambulance: _selectedAmbulance!,
                patientLocation:
                    locationAsync.valueOrNull ?? const LatLng(0.3136, 32.5811),
                onDismiss: () => setState(() => _selectedAmbulance = null),
              ),
            ),

          // ── Re-center button ─────────────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              tooltip: 'Centre on my location',
              onPressed: () {
                final loc = locationAsync.valueOrNull;
                if (loc != null) {
                  _mapController.move(loc, 14);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Active trip banner (tap → open tracking screen) ──────────────
          if (hasActiveTrip)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => context
                    .push('/patient/tracking/${activeTrip.id}'),
                child: _ActiveTripBanner(incident: activeTrip),
              ),
            ),

          // ── Request button ────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: hasActiveTrip
                  ? null
                  : () => context.push('/patient/request'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.error.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
              ),
              icon: const Icon(Icons.emergency, size: 22),
              label: const Text(
                'Request Ambulance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng center, List<Ambulance> ambulances) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        onTap: (_, __) => setState(() => _selectedAmbulance = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.erams.erams',
        ),
        // Patient location marker (blue pulsing pin)
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 48,
              height: 48,
              child: const _PatientMarker(),
            ),
          ],
        ),
        // Ambulance markers — numbered green pins
        MarkerLayer(
          markers: ambulances
              .where((a) => a.latitude != null && a.longitude != null)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Marker(
              point: LatLng(a.latitude!, a.longitude!),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => setState(() => _selectedAmbulance = a),
                child: _AmbulanceMarker(number: i + 1, serviceType: a.serviceType),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Patient location marker (blue circle with cross-hair) ─────────────────────

class _PatientMarker extends StatelessWidget {
  const _PatientMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 20),
    );
  }
}

// ── Numbered ambulance marker ─────────────────────────────────────────────────

class _AmbulanceMarker extends StatelessWidget {
  final int number;
  final ServiceType serviceType;

  const _AmbulanceMarker({required this.number, required this.serviceType});

  Color get _color => switch (serviceType) {
    ServiceType.bls       => const Color(0xFF2E7D32),
    ServiceType.als       => const Color(0xFFE65100),
    ServiceType.icu       => const Color(0xFFC62828),
    ServiceType.neonatal  => const Color(0xFF880E4F),
    ServiceType.bariatric => const Color(0xFF4A148C),
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Pin body
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Center(
            child: Text(
              number.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Available count chip ──────────────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.primary : AppColors.error,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x30000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            count > 0 ? Icons.airport_shuttle : Icons.warning_amber,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            count > 0
                ? '$count ambulance${count == 1 ? '' : 's'} available nearby'
                : 'No ambulances available right now',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Ambulance info card (shown when marker is tapped) ─────────────────────────

class _AmbulanceInfoCard extends StatelessWidget {
  final Ambulance ambulance;
  final LatLng patientLocation;
  final VoidCallback onDismiss;

  const _AmbulanceInfoCard({
    required this.ambulance,
    required this.patientLocation,
    required this.onDismiss,
  });

  double? get _distanceKm {
    if (ambulance.latitude == null || ambulance.longitude == null) return null;
    // Haversine approximation
    const r = 6371.0;
    final dLat = _toRad(ambulance.latitude! - patientLocation.latitude);
    final dLng = _toRad(ambulance.longitude! - patientLocation.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(patientLocation.latitude)) *
            math.cos(_toRad(ambulance.latitude!)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  String get _fareEstimate {
    final dist = _distanceKm ?? 5.0;
    final total = ambulance.baseFare + dist * ambulance.pricePerKm;
    return 'UGX ${total.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.airport_shuttle, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ambulance.plateNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip(
                  label: ambulance.serviceType.shortLabel,
                  color: AppColors.primary,
                ),
                if (_distanceKm != null)
                  _Chip(
                    label: '${_distanceKm!.toStringAsFixed(1)} km away',
                    color: Colors.blueGrey,
                  ),
                _Chip(label: _fareEstimate, color: Colors.green.shade700),
                if (ambulance.ratingCount > 0)
                  _Chip(
                    label: '★ ${ambulance.rating.toStringAsFixed(1)}',
                    color: Colors.amber.shade700,
                  ),
              ],
            ),
            if (ambulance.equipmentNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ambulance.equipmentNotes,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Active trip status banner ─────────────────────────────────────────────────

class _ActiveTripBanner extends StatelessWidget {
  final Incident incident;
  const _ActiveTripBanner({required this.incident});

  @override
  Widget build(BuildContext context) {
    final isPending =
        incident.status == IncidentStatus.pendingAcceptance;
    final color =
        isPending ? AppColors.statusPending : AppColors.statusEnRoute;
    final message = switch (incident.status) {
      IncidentStatus.pendingAcceptance =>
        'Waiting for driver to accept your request…',
      IncidentStatus.dispatched => 'Ambulance dispatched — on the way!',
      IncidentStatus.enRoute    => 'Ambulance is en route to you',
      IncidentStatus.arrived    => 'Ambulance has arrived',
      _                         => 'Active trip in progress',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPending
                ? Icons.access_time_rounded
                : Icons.airport_shuttle_outlined,
            color: Colors.white,
            size: 20,
          ),
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
