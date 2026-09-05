import 'profile.dart';

class Driver {
  final String id;
  final String name;
  final double rating;
  final bool verified;
  final int trips;

  Driver({
    required this.id,
    required this.name,
    required this.rating,
    required this.verified,
    this.trips = 0,
  });

  factory Driver.fromProfile(Profile profile) {
    return Driver(
      id: profile.id,
      name: profile.name,
      rating: profile.rating,
      verified: true,
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'D';
}
