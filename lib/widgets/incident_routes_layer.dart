import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../models/ambulance.dart';
import '../models/incident.dart';
import '../state/routing_provider.dart';

/// Map layer that highlights, for every incident an ambulance is actively
/// driving to, the shortest road route between that ambulance's live location
/// and the patient/incident location.
///
/// This mirrors the route highlight the patient and driver already see, so the
/// dispatcher and admin live maps show the same picture the moment a driver
/// accepts a request (incident → `dispatched`) and while it is en route or has
/// arrived. Incidents that are still `logged` or `pending_acceptance` (nobody
/// has accepted yet) are intentionally skipped.
///
/// Drop it into a [FlutterMap]'s `children` right after the tile layer and
/// before the marker layers, so markers render on top of the routes.
class IncidentRoutesLayer extends ConsumerWidget {
  final List<Incident> incidents;
  final List<Ambulance> ambulances;

  const IncidentRoutesLayer({
    super.key,
    required this.incidents,
    required this.ambulances,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dashed fallbacks first so the solid road routes paint on top of them.
    final dashed = <Polyline>[];
    final solid = <Polyline>[];

    for (final incident in incidents) {
      // Only once a driver has accepted (dispatched) and while the trip is
      // still under way. Skips logged / pending_acceptance / completed /
      // cancelled.
      final underway = incident.status == IncidentStatus.dispatched ||
          incident.status == IncidentStatus.enRoute ||
          incident.status == IncidentStatus.arrived;
      if (!underway) continue;

      final ambId = incident.assignedAmbulanceId;
      if (ambId == null) continue;
      if (incident.latitude == null || incident.longitude == null) continue;

      final ambulance = _ambulanceById(ambId);
      if (ambulance == null ||
          ambulance.latitude == null ||
          ambulance.longitude == null) {
        continue;
      }

      final from = LatLng(ambulance.latitude!, ambulance.longitude!);
      final to = LatLng(incident.latitude!, incident.longitude!);

      final route =
          ref.watch(routeProvider(routeCacheKey(from, to))).valueOrNull;

      if (route != null) {
        // Highlighted shortest road route the ambulance will follow.
        solid.add(
          Polyline(
            points: route.points,
            color: AppColors.statusEnRoute,
            strokeWidth: 5,
            borderColor: Colors.white,
            borderStrokeWidth: 1.5,
          ),
        );
      } else {
        // Straight dashed line while the route loads or the routing server is
        // unreachable.
        dashed.add(
          Polyline(
            points: [from, to],
            color: AppColors.statusEnRoute.withValues(alpha: 0.45),
            strokeWidth: 2.5,
            isDotted: true,
          ),
        );
      }
    }

    return PolylineLayer(polylines: [...dashed, ...solid]);
  }

  Ambulance? _ambulanceById(String id) {
    for (final a in ambulances) {
      if (a.id == id) return a;
    }
    return null;
  }
}
