import 'package:flutter_test/flutter_test.dart';
import 'package:ganti/core/services/weather_service.dart';

// Manual probe: hits the live data.gov.my weather/warning + weather/forecast
// endpoints and prints the safety alerts the app would show. Skipped by default
// so `flutter test` stays offline-safe; run it on demand with:
//
//   flutter test --plain-name "live data.gov.my alerts" test/weather_warning_probe.dart
//
// (remove `skip:` first, or pass --run-skipped).
void main() {
  test('live data.gov.my alerts', () async {
    final alerts = await WeatherService().fetchAlerts(force: true);
    // ignore: avoid_print
    print('\n--- ${alerts.length} alert(s) ---');
    for (final a in alerts) {
      // ignore: avoid_print
      print('[${a.type.name}/${a.severity.name}] ${a.title}\n'
          '  area: ${a.area}  loc: ${a.location}\n'
          '  ${a.description.replaceAll("\n", " / ")}\n'
          '  source: ${a.source}\n');
    }
    expect(alerts, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)), skip: 'hits the network');
}
