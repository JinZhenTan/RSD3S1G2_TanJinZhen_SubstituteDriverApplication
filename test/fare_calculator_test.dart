import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ganti/features/booking/services/fare_calculator.dart';
import 'package:ganti/models/booking.dart';
import 'package:ganti/models/route_result.dart';
import 'package:ganti/models/weather_alert.dart';

// Unit tests for the fare-calculation algorithm (CLAUDE.md §4, Module 1).
// Pure logic, no Flutter/Supabase needed.
void main() {
  RouteResult routeOf(double km) => RouteResult(
        points: const [LatLng(5.42, 100.33), LatLng(5.47, 100.31)],
        distanceKm: km,
        duration: Duration(minutes: (km * 2).round()),
      );

  group('FareCalculator', () {
    test('short trip under 10 km is just the flagfall', () {
      final fare = FareCalculator.calculate(
        tier: ServiceTier.standard,
        route: routeOf(6),
        activeAlerts: const [],
      );
      expect(fare.total, ServiceTier.standard.flagfall);
      expect(fare.lines.length, 1);
    });

    test('distance beyond 10 km is charged at the per-km rate', () {
      final fare = FareCalculator.calculate(
        tier: ServiceTier.standard,
        route: routeOf(14),
        activeAlerts: const [],
      );
      // 8.00 flagfall + 4 km * 1.20 = 12.80
      expect(fare.total, closeTo(12.80, 0.001));
    });

    test('wet-weather buffer is added when a hazard sits on the route', () {
      final hazardOnRoute = WeatherAlert(
        id: 'x',
        type: AlertType.flood,
        severity: AlertSeverity.severe,
        title: 'Flood',
        description: '',
        area: '',
        source: '',
        createdAt: DateTime.now(),
        location: const LatLng(5.42, 100.33), // == first route point
      );
      final fare = FareCalculator.calculate(
        tier: ServiceTier.standard,
        route: routeOf(6),
        activeAlerts: [hazardOnRoute],
      );
      // flagfall 8.00 + 2.00 wet-weather buffer
      expect(fare.total, closeTo(10.00, 0.001));
    });

    test('hourly tier ignores distance and bills per full hour', () {
      // routeOf(40) => 80 minutes, rounded up to 2 whole hours * RM35.
      final fare = FareCalculator.calculate(
        tier: ServiceTier.hourly,
        route: routeOf(40),
        activeAlerts: const [],
      );
      expect(fare.total, closeTo(70.0, 0.001));
      expect(fare.lines.first.label, contains('Hourly rate'));
    });
  });
}
