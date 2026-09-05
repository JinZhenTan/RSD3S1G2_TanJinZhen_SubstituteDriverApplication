// Models for Module 3 (Vehicle Services).
//
// A company driver collects the user's car (owner not present), takes it for
// servicing and returns it. Payment happens AFTER the car is returned.

// The 6 steps shown on the Status Tracker screen, in order, plus 'cancelled'
// as a terminal state outside that ladder (same idea as BookingStatus's
// separate 'cancelled' - not a 7th step). 'returning' is its own step between
// the service work finishing and the car actually being back with the owner -
// the staff page for it (ServiceReturnScreen) drives from the service centre
// back to the original pick-up address. The 'status' column stores the enum
// name.
enum CarServiceStatus {
  requested,
  assigned,
  pickedUp,
  atCentre,
  returning,
  returned,
  cancelled,
}

// The 6 steps that actually appear on the tracker's timeline - use this
// instead of CarServiceStatus.values wherever "step N of 6" / "the next
// step" arithmetic is meant (stepIndex, advanceStatus), since that list
// would otherwise silently include 'cancelled'.
const List<CarServiceStatus> carServiceTrackableSteps = [
  CarServiceStatus.requested,
  CarServiceStatus.assigned,
  CarServiceStatus.pickedUp,
  CarServiceStatus.atCentre,
  CarServiceStatus.returning,
  CarServiceStatus.returned,
];

// Human-readable label for a status step (like the emojiIcon helper in the
// SQLite practical). "Returned to you" reads correctly on the owner's own
// screens, but not on the staff's - from their side nothing was returned to
// *them*, so forStaff drops that "to you" (the only wording that differs).
String carServiceStatusLabel(CarServiceStatus status, {bool forStaff = false}) {
  switch (status) {
    case CarServiceStatus.requested:
      return 'Requested';
    case CarServiceStatus.assigned:
      return 'Driver assigned';
    case CarServiceStatus.pickedUp:
      return 'Picked up';
    case CarServiceStatus.atCentre:
      return 'At service centre';
    case CarServiceStatus.returning:
      return forStaff ? 'On the way back' : 'On the way back to you';
    case CarServiceStatus.returned:
      return forStaff ? 'Returned' : 'Returned to you';
    case CarServiceStatus.cancelled:
      return 'Cancelled';
  }
}

CarServiceStatus carServiceStatusFromName(String? name) {
  for (final s in CarServiceStatus.values) {
    if (s.name == name) return s;
  }
  return CarServiceStatus.requested;
}

// A service type offered on the booking form. Each one has one fixed price
// shown before the car is serviced - not a range, so the owner knows exactly
// what they'll pay before booking. (A real workshop would still quote a
// range since the exact parts/labour needed vary per car, but a flat price
// per type keeps this assignment's booking flow simple to follow.)
// estimateMin/estimateMax are kept as computed getters (both equal to
// `price`) purely so call sites written for the old min/max range don't all
// need to change - they now just read the same fixed number twice.
class CarServiceType {
  final String name;
  final String label;
  final int price;

  const CarServiceType({
    required this.name,
    required this.label,
    required this.price,
  });

  int get estimateMin => price;
  int get estimateMax => price;

  static const general = CarServiceType(
    name: 'general',
    label: 'General maintenance',
    price: 160,
  );
  static const oilFilter = CarServiceType(
    name: 'oilFilter',
    label: 'Oil & filter change',
    price: 130,
  );
  static const tyre = CarServiceType(
    name: 'tyre',
    label: 'Tyre rotation / replacement',
    price: 150,
  );
  static const battery = CarServiceType(
    name: 'battery',
    label: 'Battery check & replacement',
    price: 120,
  );
  static const wash = CarServiceType(
    name: 'wash',
    label: 'Car wash & detailing',
    price: 80,
  );
  static const inspection = CarServiceType(
    name: 'inspection',
    label: 'Full inspection',
    price: 200,
  );

  static const all = [general, oilFilter, tyre, battery, wash, inspection];

  factory CarServiceType.fromName(String? name) {
    return all.firstWhere(
      (t) => t.name == name,
      orElse: () => general,
    );
  }
}

// Reads service_types (the multi-select array) when present, falling back to
// the single legacy service_type column for rows saved before multi-select
// existed.
List<CarServiceType> _serviceTypesFromJson(Map<String, dynamic> json) {
  final raw = json['service_types'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map((n) => CarServiceType.fromName(n as String?)).toList();
  }
  return [CarServiceType.fromName(json['service_type'] as String?)];
}

// Model class for a row of the Supabase 'car_service_requests' table.
class CarServiceRequest {
  final String id;
  final String userId;
  final String? vehicleId;
  final String? driverId;
  final DateTime pickupDatetime;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  // A booking can cover more than one kind of service in the same visit
  // (e.g. oil change + tyre rotation) - always at least one entry.
  final List<CarServiceType> serviceTypes;
  final int costEstimateMin;
  final int costEstimateMax;
  final double? finalCost;
  final double? finalLabour;
  final double? finalParts;
  final double? finalInspection;
  final double? finalTransport;
  final String? serviceCentreId;
  final double? staffLat; // live position of the service staff
  final double? staffLng;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? atCentreAt;
  final DateTime? returningAt;
  final DateTime? returnedAt;
  final int? odometerIn;
  final int? odometerOut;
  final DateTime? readyBy;
  final CarServiceStatus status;
  final String paymentStatus;
  final String? notes;
  // Why the owner cancelled - required (see CarServiceProvider.cancelRequest)
  // since cancelling is only offered once a request/staff exists to explain
  // to.
  final String? cancellationReason;
  final DateTime createdAt;

  CarServiceRequest({
    required this.id,
    required this.userId,
    this.vehicleId,
    this.driverId,
    required this.pickupDatetime,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    required this.serviceTypes,
    required this.costEstimateMin,
    required this.costEstimateMax,
    this.finalCost,
    this.finalLabour,
    this.finalParts,
    this.finalInspection,
    this.finalTransport,
    this.serviceCentreId,
    this.staffLat,
    this.staffLng,
    this.assignedAt,
    this.pickedUpAt,
    this.atCentreAt,
    this.returningAt,
    this.returnedAt,
    this.odometerIn,
    this.odometerOut,
    this.readyBy,
    required this.status,
    required this.paymentStatus,
    this.notes,
    this.cancellationReason,
    required this.createdAt,
  });

  factory CarServiceRequest.fromJson(Map<String, dynamic> json) {
    return CarServiceRequest(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      vehicleId: json['vehicle_id']?.toString(),
      driverId: json['driver_id']?.toString(),
      pickupDatetime:
          DateTime.tryParse(json['pickup_datetime']?.toString() ?? '') ??
          DateTime.now(),
      pickupAddress: (json['pickup_address'] ?? '') as String,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      serviceTypes: _serviceTypesFromJson(json),
      costEstimateMin: (json['cost_estimate_min'] as num?)?.toInt() ?? 0,
      costEstimateMax: (json['cost_estimate_max'] as num?)?.toInt() ?? 0,
      finalCost: (json['final_cost'] as num?)?.toDouble(),
      finalLabour: (json['final_labour'] as num?)?.toDouble(),
      finalParts: (json['final_parts'] as num?)?.toDouble(),
      finalInspection: (json['final_inspection'] as num?)?.toDouble(),
      finalTransport: (json['final_transport'] as num?)?.toDouble(),
      serviceCentreId: json['service_centre_id']?.toString(),
      staffLat: (json['staff_lat'] as num?)?.toDouble(),
      staffLng: (json['staff_lng'] as num?)?.toDouble(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? ''),
      pickedUpAt: DateTime.tryParse(json['picked_up_at']?.toString() ?? ''),
      atCentreAt: DateTime.tryParse(json['at_centre_at']?.toString() ?? ''),
      returningAt: DateTime.tryParse(json['returning_at']?.toString() ?? ''),
      returnedAt: DateTime.tryParse(json['returned_at']?.toString() ?? ''),
      odometerIn: (json['odometer_in'] as num?)?.toInt(),
      odometerOut: (json['odometer_out'] as num?)?.toInt(),
      readyBy: DateTime.tryParse(json['ready_by']?.toString() ?? ''),
      status: carServiceStatusFromName(json['status'] as String?),
      paymentStatus: (json['payment_status'] ?? 'pending') as String,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'vehicle_id': vehicleId,
      'driver_id': driverId,
      'pickup_datetime': pickupDatetime.toIso8601String(),
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'service_type': serviceTypes.first.name, // legacy single-value column
      'service_types': serviceTypes.map((t) => t.name).toList(),
      'cost_estimate_min': costEstimateMin,
      'cost_estimate_max': costEstimateMax,
      'final_cost': finalCost,
      'final_labour': finalLabour,
      'final_parts': finalParts,
      'final_inspection': finalInspection,
      'final_transport': finalTransport,
      'status': status.name,
      'payment_status': paymentStatus,
      'notes': notes,
    };
  }

  // Fixed price, not a range - costEstimateMin/Max are always equal (both
  // set from CarServiceType.price, summed across the selected types).
  String get estimateLabel => 'RM $costEstimateMin';

  // The first selected type - for the many places that just need a single
  // representative type (screen titles, receipt descriptions).
  CarServiceType get serviceType => serviceTypes.first;

  String get serviceTypesLabel => serviceTypes.map((t) => t.label).join(', ');

  // Position of the current status in the 5-step tracker (0..4), or -1 for
  // 'cancelled' - that's a terminal state outside the ladder, not a step.
  int get stepIndex => carServiceTrackableSteps.indexOf(status);

  bool get isCancelled => status == CarServiceStatus.cancelled;

  // The real itemised breakdown the service partner entered, or null if this
  // row only has a single lump-sum final_cost (older rows / demo toggle).
  Map<String, double>? get itemisedCost {
    if (finalLabour == null &&
        finalParts == null &&
        finalInspection == null &&
        finalTransport == null) {
      return null;
    }
    return {
      'Labour': finalLabour ?? 0,
      'Parts & consumables': finalParts ?? 0,
      'Inspection fee': finalInspection ?? 0,
      'Pick-up & drop-off': finalTransport ?? 0,
    };
  }

  // Returns a copy with some fields changed (used after a status update).
  CarServiceRequest copyWith({
    String? driverId,
    CarServiceStatus? status,
    double? finalCost,
    double? finalLabour,
    double? finalParts,
    double? finalInspection,
    double? finalTransport,
    String? serviceCentreId,
    double? staffLat,
    double? staffLng,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? atCentreAt,
    DateTime? returningAt,
    DateTime? returnedAt,
    int? odometerIn,
    int? odometerOut,
    DateTime? readyBy,
    String? paymentStatus,
    String? cancellationReason,
  }) {
    return CarServiceRequest(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      driverId: driverId ?? this.driverId,
      pickupDatetime: pickupDatetime,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      serviceTypes: serviceTypes,
      costEstimateMin: costEstimateMin,
      costEstimateMax: costEstimateMax,
      finalCost: finalCost ?? this.finalCost,
      finalLabour: finalLabour ?? this.finalLabour,
      finalParts: finalParts ?? this.finalParts,
      finalInspection: finalInspection ?? this.finalInspection,
      finalTransport: finalTransport ?? this.finalTransport,
      serviceCentreId: serviceCentreId ?? this.serviceCentreId,
      staffLat: staffLat ?? this.staffLat,
      staffLng: staffLng ?? this.staffLng,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      atCentreAt: atCentreAt ?? this.atCentreAt,
      returningAt: returningAt ?? this.returningAt,
      returnedAt: returnedAt ?? this.returnedAt,
      odometerIn: odometerIn ?? this.odometerIn,
      odometerOut: odometerOut ?? this.odometerOut,
      readyBy: readyBy ?? this.readyBy,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
    );
  }
}
