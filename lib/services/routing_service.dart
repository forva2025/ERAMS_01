import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A road-network route between two points.
class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

/// Computes the shortest driving route between two points over the real
/// road network (as opposed to a straight-line haversine estimate), using
/// the public OSRM (Open Source Routing Machine) API.
class RoutingService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Returns the shortest route from [from] to [to], or `null` if it could
  /// not be computed (offline, request failure, no drivable path). Callers
  /// should fall back to a straight-line estimate in that case.
  Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      '$_baseUrl/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;

      final coordinates =
          (route['geometry']['coordinates'] as List).cast<List>();
      final points = coordinates
          .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (points.length < 2) return null;

      return RouteResult(
        points: points,
        distanceKm: (route['distance'] as num).toDouble() / 1000,
        durationMin: (route['duration'] as num).toDouble() / 60,
      );
    } catch (_) {
      return null;
    }
  }
}
