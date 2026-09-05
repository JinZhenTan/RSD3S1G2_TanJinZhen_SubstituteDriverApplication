import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/forecast.dart';
import '../../models/weather_alert.dart';
import '../../models/weather_warning.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String forecastUrl = 'https://api.data.gov.my/weather/forecast';
  static const String warningUrl = 'https://api.data.gov.my/weather/warning';

  static const Map<String, String> states = {
    'St001': 'Perlis',
    'St002': 'Kedah',
    'St003': 'Pulau Pinang',
    'St004': 'Perak',
    'St005': 'Kelantan',
    'St006': 'Terengganu',
    'St007': 'Pahang',
    'St008': 'Selangor',
    'St009': 'WP Kuala Lumpur',
    'St010': 'WP Putrajaya',
    'St011': 'Negeri Sembilan',
    'St012': 'Melaka',
    'St013': 'Johor',
    'St501': 'Sarawak',
    'St502': 'Sabah',
    'St503': 'WP Labuan',
  };

  static const String defaultLocationId = 'St003';
  static const Map<String, LatLng> _stateCentre = {
    'St001': LatLng(6.4400, 100.2000),
    'St002': LatLng(6.1200, 100.3700),
    'St003': LatLng(5.4141, 100.3288),
    'St004': LatLng(4.6000, 101.0900),
    'St005': LatLng(5.2500, 102.0000),
    'St006': LatLng(5.3100, 103.1400),
    'St007': LatLng(3.8100, 103.3300),
    'St008': LatLng(3.0738, 101.5183),
    'St009': LatLng(3.1390, 101.6869),
    'St010': LatLng(2.9264, 101.6964),
    'St011': LatLng(2.7300, 101.9400),
    'St012': LatLng(2.2000, 102.2500),
    'St013': LatLng(1.8700, 103.3500),
    'St501': LatLng(1.5500, 110.3400),
    'St502': LatLng(5.9800, 116.0700),
    'St503': LatLng(5.2800, 115.2400),
  };

  List<WeatherAlert>? _cachedAlerts;
  DateTime? _cachedAt;

  Future<List<Forecast>> fetchForecast(String locationId) async {
    if (locationId.isEmpty) {
      return Future.value([]);
    }

    final url = Uri.parse(
      '$forecastUrl?contains=$locationId@location__location_id&sort=date',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        return jsonData
            .map((json) => Forecast.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load forecast : ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching forecast data : $e');
    }
  }

  Future<List<WeatherWarning>> fetchWarnings() async {
    final url = Uri.parse(warningUrl);
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        return jsonData
            .map((json) =>
                WeatherWarning.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load warnings : ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching warning data : $e');
    }
  }

  List<WeatherAlert> alertsFromWarnings(List<WeatherWarning> warnings) {
    final alerts = <WeatherAlert>[];

    for (final w in warnings) {
      if (!w.isActive) continue;
      final blob = w.blob;

      final landRelevant = _hasAny(blob, const [
        'thunderstorm',
        'ribut petir',
        'heavy rain',
        'hujan lebat',
        'hujan berterusan',
        'continuous rain',
        'flood',
        'banjir',
        'landslide',
        'tanah runtuh',
        'haze',
        'jerebu',
        'earthquake',
        'gempa',
        'tropical depression',
        'tropical storm',
        'lekukan tropika',
        'ribut tropika',
      ]);
      if (!landRelevant) continue;

      final isFlood = _hasAny(blob, const [
        'flood',
        'banjir',
        'flash flood',
        'banjir kilat',
        'continuous rain',
        'hujan berterusan',
      ]);
      final isRoad = _hasAny(blob, const [
        'landslide',
        'tanah runtuh',
        'road closed',
        'jalan ditutup',
        'road closure',
      ]);

      final AlertType type;
      if (isRoad) {
        type = AlertType.roadClosure;
      } else if (isFlood) {
        type = AlertType.flood;
      } else {
        type = AlertType.rain;
      }

      final severity = _warningSeverity(blob);
      final stateId = _stateIdFromText(blob);
      final area = stateId == null ? 'Malaysia' : states[stateId]!;
      final title = w.title_en.isNotEmpty ? w.title_en : w.heading_en;

      final body = w.heading_en.isNotEmpty ? w.heading_en : _firstSentence(w.text_en);
      final description = w.instruction_en.isEmpty
          ? _tidy(body)
          : '${_tidy(body)}\n${_tidy(w.instruction_en)}';

      alerts.add(
        WeatherAlert(
          id: 'warning-${w.issued}-${type.name}',
          type: type,
          severity: severity,
          title: area == 'Malaysia' ? title : '$title — $area',
          description: description,
          area: area,
          source: 'MetMalaysia · data.gov.my',
          createdAt: DateTime.tryParse(w.issued) ?? DateTime.now(),
          location: stateId == null ? null : _stateCentre[stateId],
        ),
      );
    }

    return alerts;
  }

  List<WeatherAlert> alertsFromForecast(List<Forecast> forecasts) {
    final alerts = <WeatherAlert>[];
    for (final f in forecasts.take(3)) {
      final blob = '${f.summary_forecast} ${f.morning_forecast} '
          '${f.afternoon_forecast} ${f.night_forecast}';
      final severity = classifySeverity(blob);
      if (severity == AlertSeverity.info) continue;

      final day = DateTime.tryParse(f.date);
      final isToday = day != null &&
          day.year == DateTime.now().year &&
          day.month == DateTime.now().month &&
          day.day == DateTime.now().day;

      alerts.add(
        WeatherAlert(
          id: 'forecast-${f.location_id}-${f.date}',
          type: AlertType.rain,
          severity: severity,
          title: severity == AlertSeverity.severe
              ? 'Thunderstorm expected — ${f.location_name}'
              : 'Rain expected — ${f.location_name}',
          description: '${f.summary_forecast} (${f.summary_when}). '
              'Morning: ${f.morning_forecast}. '
              'Afternoon: ${f.afternoon_forecast}. '
              'Night: ${f.night_forecast}.',
          area: f.location_name,
          source: 'MetMalaysia · data.gov.my',
          createdAt: DateTime.now(),
          location: _stateCentre[f.location_id],
        ),
      );

      if (isToday) break;
    }
    return alerts;
  }

  Future<List<WeatherAlert>> fetchAlerts({bool force = false}) async {
    if (!force &&
        _cachedAlerts != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(seconds: 60)) {
      return _cachedAlerts!;
    }

    final alerts = <WeatherAlert>[];
    var liveOk = false;

    try {
      alerts.addAll(alertsFromWarnings(await fetchWarnings()));
      liveOk = true;
    } catch (e) {
      print('WeatherService.fetchAlerts warning error: $e');
    }

    try {
      alerts.addAll(alertsFromForecast(await fetchForecast(defaultLocationId)));
      liveOk = true;
    } catch (e) {
      print('WeatherService.fetchAlerts forecast error: $e');
    }

    if (!liveOk || alerts.isEmpty) {
      alerts.addAll(_seededAlerts());
    }

    final seen = <String>{};
    final deduped =
        alerts.where((a) => seen.add('${a.type.name}|${a.title}')).toList()
          ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    _cachedAlerts = deduped;
    _cachedAt = DateTime.now();
    return deduped;
  }

  Future<WeatherAlert?> currentBannerAlert() async {
    final alerts = await fetchAlerts();
    for (final alert in alerts) {
      if (alert.isSafetyAlert) return alert;
    }
    return null;
  }

  AlertSeverity classifySeverity(String text) {
    final t = text.toLowerCase().replaceAll('tiada hujan', '');
    const severeWords = [
      'thunderstorm',
      'heavy rain',
      'ribut petir',
      'hujan lebat',
      'storm',
      'flood',
      'banjir',
      'danger',
    ];
    const moderateWords = ['rain', 'hujan', 'showers', 'warning', 'advisory'];
    for (final w in severeWords) {
      if (t.contains(w)) return AlertSeverity.severe;
    }
    for (final w in moderateWords) {
      if (t.contains(w)) return AlertSeverity.moderate;
    }
    return AlertSeverity.info;
  }

  AlertSeverity _warningSeverity(String blob) {
    const severeWords = [
      'danger',
      'berbahaya',
      'first category',
      'kategori pertama',
      'red',
      'merah',
      'flash flood',
      'banjir kilat',
    ];
    for (final w in severeWords) {
      if (blob.contains(w)) return AlertSeverity.severe;
    }
    return AlertSeverity.moderate;
  }

  String? _stateIdFromText(String blob) {
    for (final entry in states.entries) {
      final name = entry.value.toLowerCase().replaceAll('wp ', '');
      if (blob.contains(name)) return entry.key;
    }
    return null;
  }

  bool _hasAny(String blob, List<String> words) {
    for (final w in words) {
      if (blob.contains(w)) return true;
    }
    return false;
  }

  String _firstSentence(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final end = t.indexOf('. ');
    return end == -1 ? t : t.substring(0, end + 1);
  }

  String _tidy(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 240) t = '${t.substring(0, 237)}...';
    if (t == t.toUpperCase() && t.length > 12) {
      t = t.toLowerCase();
      t = t[0].toUpperCase() + t.substring(1);
    }
    return t;
  }

  List<WeatherAlert> _seededAlerts() {
    final now = DateTime.now();
    return [
      WeatherAlert(
        id: 'seed-flood',
        type: AlertType.flood,
        severity: AlertSeverity.severe,
        title: 'Flooded road — Jalan Burma',
        description:
            'Water level above 30cm reported near the Burma–Kelawai junction. '
            'Avoid or detour via Jalan Kelawai.',
        area: 'Timur Laut, Pulau Pinang',
        source: 'Offline fallback',
        createdAt: now.subtract(const Duration(minutes: 4)),
        location: const LatLng(5.4300, 100.3180),
      ),
      WeatherAlert(
        id: 'seed-rain',
        type: AlertType.rain,
        severity: AlertSeverity.moderate,
        title: 'Heavy rain warning — Timur Laut',
        description:
            'MetMalaysia forecasts continuous heavy rain until 9:00 PM. '
            'Expect reduced visibility on coastal roads.',
        area: 'Timur Laut, Pulau Pinang',
        source: 'Offline fallback',
        createdAt: now.subtract(const Duration(minutes: 20)),
        location: const LatLng(5.4560, 100.3080),
      ),
    ];
  }
}
