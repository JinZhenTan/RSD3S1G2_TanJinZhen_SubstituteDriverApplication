import 'package:latlong2/latlong.dart';

// Model class for a row of the Supabase 'service_centres' table (Module 3).
//
// A small seeded set of workshops. The service staff picks which centre a job
// goes to when they accept it; both the staff map and the owner's Status
// Tracker then show the centre pin and the leg to / from it.
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
