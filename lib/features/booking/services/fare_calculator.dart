import 'package:latlong2/latlong.dart';

import '../../../models/booking.dart';
import '../../../models/route_result.dart';
import '../../../models/weather_alert.dart';

// One row in the fare summary (label + amount).
class FareLine {
  final String label;
  final double amount;
  const FareLine(this.label, this.amount);
}

// The full fare breakdown for a trip.
class FareBreakdown {
  final List<FareLine> lines;
  final double total;
  const FareBreakdown(this.lines, this.total);
}

// Fare-calculation logic for the "Find a Driver" service for the assignment.
//
// Rules:
//   1. The flagfall covers the first 10 km of the trip.
//   2. Every km beyond 10 km is charged at the tier's per-km rate.
//   3. A flat "wet-weather routing buffer" is added when an active weather
//      alert lies close to the planned route.
//
// The hourly tier is billed differently: a flat rate per full hour of
// estimated travel time, with no distance component.
class FareCalculator {
  static const double freeKm = 10.0;
  static const double wetWeatherBuffer = 2.00;
  static const double hazardProximityMetres = 1500;

  // True when any flagged hazard is within ~1.5 km of the route line.
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
      // Round the estimated travel time up to the next full hour.
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
