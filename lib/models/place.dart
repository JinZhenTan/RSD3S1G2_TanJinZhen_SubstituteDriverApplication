import 'package:latlong2/latlong.dart';

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

  String get shortName {
    final parts = displayName.split(',');
    return parts.take(2).join(',').trim();
  }
}
