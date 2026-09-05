import 'profile.dart';

// The substitute driver shown on the passenger's Trip Tracking screen. Built
// from the assigned driver's profile row once a real driver accepts the
// booking, or from a local placeholder in simulation mode.
//
// A substitute driver does NOT bring a vehicle - they drive the passenger's
// own car - so there is no plate / vehicle info here, only the driver's
// identity, rating and trip count.
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
