import 'package:latlong2/latlong.dart';

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
