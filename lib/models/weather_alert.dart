import 'package:latlong2/latlong.dart';

// Models for Module 2 (Weather & Safety Alerts).

// Severity buckets, used to colour the alert cards and decide the wet-weather
// fare surcharge. Classification is done in WeatherService.
enum AlertSeverity { info, moderate, severe }

// The kind of hazard, drives the icon on the card.
enum AlertType { flood, rain, roadClosure, tripUpdate }

// A safety alert or feed item. Flood / road-closure / thunderstorm alerts are
// parsed from data.gov.my's weather/warning + weather/forecast endpoints (see
// WeatherService); a seeded pair is the offline fallback; trip updates are
// generated locally by the booking flow.
class WeatherAlert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String area;
  final String source;
  final DateTime createdAt;
  // Optional hazard coordinate. When set, the safe-route logic tries to keep
  // the driving route away from this point.
  final LatLng? location;

  WeatherAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.area,
    required this.source,
    required this.createdAt,
    this.location,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      id: json['id'].toString(),
      type: _typeFromString(json['type'] as String?),
      severity: _severityFromString(json['severity'] as String?),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      area: (json['area'] ?? '') as String,
      source: (json['source'] ?? 'data.gov.my') as String,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      location: (json['lat'] != null && json['lng'] != null)
          ? LatLng(
              (json['lat'] as num).toDouble(),
              (json['lng'] as num).toDouble(),
            )
          : null,
    );
  }

  bool get isSafetyAlert => type != AlertType.tripUpdate;

  static AlertType _typeFromString(String? value) {
    switch (value) {
      case 'flood':
        return AlertType.flood;
      case 'rain':
        return AlertType.rain;
      case 'road_closure':
        return AlertType.roadClosure;
      default:
        return AlertType.tripUpdate;
    }
  }

  static AlertSeverity _severityFromString(String? value) {
    switch (value) {
      case 'severe':
        return AlertSeverity.severe;
      case 'moderate':
        return AlertSeverity.moderate;
      default:
        return AlertSeverity.info;
    }
  }
}
