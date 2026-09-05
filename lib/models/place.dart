import 'package:latlong2/latlong.dart';

// One address suggestion returned by the OSM Nominatim geocoding API.
class Place {
  final String displayName;
  final LatLng position;

  Place({required this.displayName, required this.position});

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      displayName: json['display_name'] as String,
      position: LatLng(
        double.parse(json['lat'].toString()),
        double.parse(json['lon'].toString()),
      ),
    );
  }

  // A shorter label. Nominatim display names can be very long.
  String get shortName {
    final parts = displayName.split(',');
    return parts.take(2).join(',').trim();
  }
}
