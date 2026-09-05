
class ServiceTier {
  final String name;
  final String label;
  final String rateLabel;
  final String description;
  final double flagfall;
  final double perKm;

  const ServiceTier({
    required this.name,
    required this.label,
    required this.rateLabel,
    required this.description,
    required this.flagfall,
    required this.perKm,
  });

  static const standard = ServiceTier(
    name: 'standard',
    label: 'Standard',
    rateLabel: 'RM8 flagfall',
    description: 'The everyday choice for a point-to-point booking with a '
        'substitute driver.',
    flagfall: 8.0,
    perKm: 1.20,
  );
  static const nightSafety = ServiceTier(
    name: 'nightSafety',
    label: 'Night Safety',
    rateLabel: 'RM10 flagfall',
    description: 'For late nights or after drinking. A higher flat rate '
        'reflects the driver risk and lower driver availability at night - '
        'not a discount, a premium.',
    flagfall: 10.0,
    perKm: 1.40,
  );
  static const verifiedPro = ServiceTier(
    name: 'verifiedPro',
    label: 'Verified Pro',
    rateLabel: 'RM15 flagfall',
    description: 'A senior, top-rated verified driver - same car, more '
        'experience. Good for business bookings, VIP pick-ups, or extra '
        'peace of mind.',
    flagfall: 15.0,
    perKm: 2.00,
  );
  static const hourly = ServiceTier(
    name: 'hourly',
    label: 'Hourly',
    rateLabel: 'RM35 / hr',
    description: 'The driver waits and drives you between multiple stops '
        '(e.g. dinner, then home). Billed per full hour instead of per km.',
    flagfall: 35.0,
    perKm: 0.0,
  );

  static const all = [standard, nightSafety, verifiedPro, hourly];

  factory ServiceTier.fromName(String? name) {
    return all.firstWhere(
      (t) => t.name == name,
      orElse: () => standard,
    );
  }
}

enum BookingStatus { searching, enRoute, onTrip, arrived, completed, cancelled }

bool bookingIsHistory(BookingStatus status) =>
    status == BookingStatus.completed || status == BookingStatus.cancelled;

String bookingStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.searching:
      return 'Finding a driver';
    case BookingStatus.enRoute:
      return 'Driver en route';
    case BookingStatus.onTrip:
      return 'Driving in progress';
    case BookingStatus.arrived:
      return 'Arrived - awaiting your confirmation';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.cancelled:
      return 'Cancelled';
  }
}

class Booking {
  final String id;
  final String userId;
  final String? driverId;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double destLat;
  final double destLng;
  final String destAddress;
  final ServiceTier serviceTier;
  final double fareEstimate;
  final double? fareFinal;
  final String paymentMethod;
  final String paymentStatus;
  final BookingStatus status;
  final String? vehicleId;
  final double? driverLat;
  final double? driverLng;
  final double? driverStartLat;
  final double? driverStartLng;
  final String? completedBy;
  final String? completionNote;
  final String? cancellationReason;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.userId,
    this.driverId,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.destLat,
    required this.destLng,
    required this.destAddress,
    required this.serviceTier,
    required this.fareEstimate,
    this.fareFinal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    this.vehicleId,
    this.driverLat,
    this.driverLng,
    this.driverStartLat,
    this.driverStartLng,
    this.completedBy,
    this.completionNote,
    this.cancellationReason,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      driverId: json['driver_id']?.toString(),
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      pickupAddress: (json['pickup_address'] ?? '') as String,
      destLat: (json['dest_lat'] as num).toDouble(),
      destLng: (json['dest_lng'] as num).toDouble(),
      destAddress: (json['dest_address'] ?? '') as String,
      serviceTier: ServiceTier.fromName(json['service_tier'] as String?),
      fareEstimate: (json['fare_estimate'] as num?)?.toDouble() ?? 0,
      fareFinal: (json['fare_final'] as num?)?.toDouble(),
      paymentMethod: (json['payment_method'] ?? 'Cash') as String,
      paymentStatus: (json['payment_status'] ?? 'pending') as String,
      status: _statusFromName(json['status'] as String?),
      vehicleId: json['vehicle_id']?.toString(),
      driverLat: (json['driver_lat'] as num?)?.toDouble(),
      driverLng: (json['driver_lng'] as num?)?.toDouble(),
      driverStartLat: (json['driver_start_lat'] as num?)?.toDouble(),
      driverStartLng: (json['driver_start_lng'] as num?)?.toDouble(),
      completedBy: json['completed_by'] as String?,
      completionNote: json['completion_note'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'driver_id': driverId,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'dest_address': destAddress,
      'service_tier': serviceTier.name,
      'fare_estimate': fareEstimate,
      'fare_final': fareFinal,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'status': status.name,
      'vehicle_id': vehicleId,
    };
  }

  String get routeLabel => '$pickupAddress → $destAddress';

  Booking copyWith({
    String? driverId,
    BookingStatus? status,
    double? fareFinal,
    double? driverLat,
    double? driverLng,
    double? driverStartLat,
    double? driverStartLng,
    String? completedBy,
    String? completionNote,
    String? cancellationReason,
  }) {
    return Booking(
      id: id,
      userId: userId,
      driverId: driverId ?? this.driverId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      pickupAddress: pickupAddress,
      destLat: destLat,
      destLng: destLng,
      destAddress: destAddress,
      serviceTier: serviceTier,
      fareEstimate: fareEstimate,
      fareFinal: fareFinal ?? this.fareFinal,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      status: status ?? this.status,
      vehicleId: vehicleId,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      driverStartLat: driverStartLat ?? this.driverStartLat,
      driverStartLng: driverStartLng ?? this.driverStartLng,
      completedBy: completedBy ?? this.completedBy,
      completionNote: completionNote ?? this.completionNote,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
    );
  }

  static BookingStatus _statusFromName(String? name) {
    for (final s in BookingStatus.values) {
      if (s.name == name) return s;
    }
    return BookingStatus.searching;
  }
}
