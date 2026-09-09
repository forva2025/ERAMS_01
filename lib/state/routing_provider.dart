import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../services/routing_service.dart';

/// Shortest road route between two points. Keyed by [routeCacheKey] so
/// callers should build the key with that helper rather than passing raw
/// coordinates straight from a GPS/Realtime feed.
final routeProvider =
    FutureProvider.family.autoDispose<RouteResult?, (LatLng, LatLng)>(
  (ref, key) => RoutingService().getRoute(key.$1, key.$2),
);

/// Rounds both points to ~11m precision so small GPS jitter while the
/// ambulance is stationary or slow-moving doesn't trigger a re-fetch
/// against the routing server on every location tick.
(LatLng, LatLng) routeCacheKey(LatLng from, LatLng to) {
  LatLng round(LatLng p) => LatLng(
        (p.latitude * 10000).round() / 10000,
        (p.longitude * 10000).round() / 10000,
      );
  return (round(from), round(to));
}
