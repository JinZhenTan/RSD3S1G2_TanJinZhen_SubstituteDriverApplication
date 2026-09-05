import 'package:latlong2/latlong.dart';

import '../../../models/booking.dart';
import '../../../models/route_result.dart';
import '../../../models/weather_alert.dart';

class FareLine {
  final String label;
  final double amount;
  const FareLine(this.label, this.amount);
}

class FareBreakdown {
  final List<FareLine> lines;
  final double total;
  const FareBreakdown(this.lines, this.total);
}

class FareCalculator {
  static const double freeKm = 10.0;
  static const double wetWeatherBuffer = 2.00;
  static const double hazardProximityMetres = 1500;

  static bool routeHitsHazard(
    List<LatLng> routePoints,
    List<WeatherAlert> alerts,
  ) {
    const distance = Distance();
    final hazards = <LatLng>[];
    for (final alert in alerts) {
      if (alert.isSafetyAlert && alert.location != null) {
        hazards.add(alert.location!);
      }
    }
    if (hazards.isEmpty || routePoints.isEmpty) return false;

    for (final p in routePoints) {
      for (final h in hazards) {
        if (distance.as(LengthUnit.Meter, p, h) <= hazardProximityMetres) {
          return true;
        }
      }
    }
    return false;
  }

  static FareBreakdown calculate({
    required ServiceTier tier,
    required RouteResult route,
    required List<WeatherAlert> activeAlerts,
  }) {
    final lines = <FareLine>[];
    final wet = routeHitsHazard(route.points, activeAlerts);

    if (tier.name == 'hourly') {
      final hours = (route.durationMinutes / 60).ceil().clamp(1, 24);
      final base = tier.flagfall * hours;
      lines.add(FareLine(
        'Hourly rate · $hours hr × '
        'RM${tier.flagfall.toStringAsFixed(0)}',
        base,
      ));
      if (wet) {
        lines.add(const FareLine('Wet-weather routing buffer', wetWeatherBuffer));
      }
      return _breakdown(lines);
    }

    lines.add(FareLine('Flagfall (first 10 km)', tier.flagfall));

    final extraKm = (route.distanceKm - freeKm).clamp(0, double.infinity).toDouble();
    if (extraKm > 0) {
      final charge = _round(extraKm * tier.perKm);
      lines.add(FareLine(
        'Extra distance · ${extraKm.toStringAsFixed(1)} km × '
        'RM${tier.perKm.toStringAsFixed(2)}',
        charge,
      ));
    }

    if (wet) {
      lines.add(const FareLine('Wet-weather routing buffer', wetWeatherBuffer));
    }

    return _breakdown(lines);
  }

  static FareBreakdown _breakdown(List<FareLine> lines) {
    double total = 0;
    for (final line in lines) {
      total += line.amount;
    }
    return FareBreakdown(lines, _round(total));
  }

  static double _round(double value) => (value * 100).round() / 100;
}
