import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../services/patient_service.dart';
import '../../widgets/error_state.dart';

class AmbulancePickerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> formData;

  const AmbulancePickerScreen({super.key, required this.formData});

  @override
  ConsumerState<AmbulancePickerScreen> createState() =>
      _AmbulancePickerScreenState();
}

class _AmbulancePickerScreenState
    extends ConsumerState<AmbulancePickerScreen> {
  String? _selecting;

  double get _lat => (widget.formData['latitude'] as num).toDouble();
  double get _lng => (widget.formData['longitude'] as num).toDouble();

  Future<void> _select(Ambulance ambulance) async {
    setState(() => _selecting = ambulance.id);
    try {
      final incident = await PatientService().createPatientIncident(
        natureOfEmergency:     widget.formData['nature_of_emergency'] as String,
        patientConditionNotes: widget.formData['patient_condition_notes'] as String,
        latitude:              _lat,
        longitude:             _lng,
        ambulanceId:           ambulance.id,
      );

      if (!mounted) return;
      // Go directly to live tracking — skip the home screen interim
      context.go('/patient/tracking/${incident.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        // The ambulance list can go stale between load and tap (another
        // patient/dispatcher may have taken it) — refresh so the retry
        // reflects current availability instead of repeating the same
        // failure against the same list.
        ref.invalidate(
            _nearbyAmbulancesForLocationProvider(LatLng(_lat, _lng)));
      }
    } finally {
      if (mounted) setState(() => _selecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientLatLng = LatLng(_lat, _lng);

    // We watch a fresh fetch scoped to this location
    final ambulancesAsync = ref.watch(
      _nearbyAmbulancesForLocationProvider(patientLatLng),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Ambulance'),
            Text(
              widget.formData['nature_of_emergency'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ambulancesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          icon: Icons.airport_shuttle_outlined,
          onRetry: () =>
              ref.invalidate(_nearbyAmbulancesForLocationProvider),
        ),
        data: (ambulances) {
          if (ambulances.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.airport_shuttle_outlined,
                        size: 64, color: AppColors.textHint),
                    SizedBox(height: 16),
                    Text(
                      'No ambulances available nearby right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please try again in a few minutes or call the emergency hotline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ambulances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final amb = ambulances[i];
              final isSelecting = _selecting == amb.id;
              return _AmbulanceCard(
                ambulance: amb,
                rank: i + 1,
                patientLocation: patientLatLng,
                isSelecting: isSelecting,
                disabled: _selecting != null,
                onSelect: () => _select(amb),
              );
            },
          );
        },
      ),
    );
  }
}

// Provider scoped to a specific location (avoids sharing with home screen state)
final _nearbyAmbulancesForLocationProvider =
    FutureProvider.family.autoDispose<List<Ambulance>, LatLng>((ref, loc) {
  return PatientService().fetchNearbyAmbulances(loc.latitude, loc.longitude);
});

// ---------------------------------------------------------------------------

class _AmbulanceCard extends StatelessWidget {
  final Ambulance ambulance;
  final int rank;
  final LatLng patientLocation;
  final bool isSelecting;
  final bool disabled;
  final VoidCallback onSelect;

  const _AmbulanceCard({
    required this.ambulance,
    required this.rank,
    required this.patientLocation,
    required this.isSelecting,
    required this.disabled,
    required this.onSelect,
  });

  double? get _distanceKm {
    if (ambulance.latitude == null || ambulance.longitude == null) return null;
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
    final dist = _distanceKm;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: rank == 1
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rank badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rank == 1
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rank == 1 ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ambulance.plateNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      _Tag(
                          label: ambulance.serviceType.shortLabel,
                          color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (dist != null)
                        _Tag(
                            label: '${dist.toStringAsFixed(1)} km',
                            color: Colors.blueGrey),
                      _Tag(
                          label: _fareEstimate,
                          color: Colors.green.shade700),
                      if (ambulance.ratingCount > 0)
                        _Tag(
                            label:
                                '★ ${ambulance.rating.toStringAsFixed(1)}',
                            color: Colors.amber.shade700),
                    ],
                  ),
                  if (ambulance.equipmentNotes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      ambulance.equipmentNotes,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Select button
            FilledButton(
              onPressed: disabled ? null : onSelect,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(72, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSelecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Select',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}
