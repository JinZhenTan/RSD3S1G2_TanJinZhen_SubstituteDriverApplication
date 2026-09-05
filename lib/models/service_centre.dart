import 'package:latlong2/latlong.dart';

class ServiceCentre {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final String openingHours;

  const ServiceCentre({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.openingHours,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory ServiceCentre.fromJson(Map<String, dynamic> json) {
    return ServiceCentre(
      id: json['id'].toString(),
      name: (json['name'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      phone: (json['phone'] ?? '') as String,
      openingHours:
          (json['opening_hours'] ?? 'Mon–Sat 9:00am–6:00pm') as String,
    );
  }
}
