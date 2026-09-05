import 'package:latlong2/latlong.dart';

// The result of an OSRM route request: the polyline to draw on the map, plus
// the total distance and travel time.
class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.duration,
  });

  int get durationMinutes => (duration.inSeconds / 60).round();
}
