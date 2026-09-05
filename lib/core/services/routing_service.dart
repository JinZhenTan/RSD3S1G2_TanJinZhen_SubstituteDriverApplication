import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/route_result.dart';
import '../../models/weather_alert.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  static const String baseUrl = 'https://router.project-osrm.org';

  Future<RouteResult> route(LatLng from, LatLng to) async {
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List;
        if (routes.isEmpty) return _straightLine(from, to);

        final first = routes.first as Map<String, dynamic>;
        return _parseRoute(first);
      } else {
        return _straightLine(from, to);
      }
    } catch (e) {
      print('RoutingService.route error: $e');
      return _straightLine(from, to);
    }
  }

  Future<RouteResult> safeRoute(
    LatLng from,
    LatLng to,
    List<WeatherAlert> hazards,
  ) async {
    final hazardPoints = <LatLng>[];
    for (final alert in hazards) {
      if (alert.location != null) hazardPoints.add(alert.location!);
    }

    final defaultRoute = await route(from, to);
    if (hazardPoints.isEmpty) return defaultRoute;

    final url = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?alternatives=true&overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return defaultRoute;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List).cast<Map<String, dynamic>>();

      RouteResult best = defaultRoute;
      double bestClearance = _minClearance(defaultRoute.points, hazardPoints);

      for (final r in routes) {
        final candidate = _parseRoute(r);
        final clearance = _minClearance(candidate.points, hazardPoints);
        if (clearance > bestClearance) {
          bestClearance = clearance;
          best = candidate;
        }
      }
      return best;
    } catch (e) {
      print('RoutingService.safeRoute error: $e');
      return defaultRoute;
    }
  }

  RouteResult _parseRoute(Map<String, dynamic> route) {
    final coords =
        (route['geometry']['coordinates'] as List).cast<List<dynamic>>();
    final points = coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return RouteResult(
      points: points,
      distanceKm: (route['distance'] as num).toDouble() / 1000.0,
      duration: Duration(seconds: (route['duration'] as num).round()),
    );
  }

  double _minClearance(List<LatLng> route, List<LatLng> hazards) {
    const distance = Distance();
    double min = double.infinity;
    for (final p in route) {
      for (final h in hazards) {
        final d = distance.as(LengthUnit.Meter, p, h);
        if (d < min) min = d;
      }
    }
    return min;
  }

  RouteResult _straightLine(LatLng from, LatLng to) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Meter, from, to) / 1000.0;
    final seconds = (km / 30.0 * 3600).round();
    return RouteResult(
      points: [from, to],
      distanceKm: km,
      duration: Duration(seconds: seconds),
    );
  }
}
