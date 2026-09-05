import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/routing_service.dart';
import '../../../supabase_config.dart';
import '../../../models/booking.dart';
import '../../../models/car_service_request.dart';
import '../../../models/driver.dart';
import '../../../models/profile.dart';
import '../../../models/receipt.dart';
import '../../../models/route_result.dart';
import '../../../models/vehicle.dart';
import '../../../models/weather_alert.dart';
import '../services/fare_calculator.dart';

// Module 1 state - the whole "Find a Driver" flow plus the Activity list.
//
// A booking is created unassigned. If a real 'driver' account accepts it the
// passenger's screens follow the live row via Supabase Realtime. If no driver
// accepts within a few seconds, a local simulation drives the trip so a solo
// demo still works (documented assumption for the assignment).
class BookingProvider extends ChangeNotifier {
  final _routing = RoutingService();

  String? get _userId => supabase.auth.currentUser?.id;

  // ---- Draft being built on the Find a Driver screen ----
  LatLng? pickup;
  String pickupAddress = '';
  LatLng? destination;
  String destAddress = '';
  ServiceTier tier = ServiceTier.standard;
  String paymentLabel = 'Cash';
  // Which of the passenger's (possibly several) cars the driver will drive -
  // defaults to their default vehicle, changeable on Find a Driver.
  Vehicle? selectedVehicle;

  RouteResult? tripRoute;
  FareBreakdown? fare;
  bool routeLoading = false;

  // ---- The active booking (after payment) ----
  Booking? activeBooking;
  Driver? activeDriver;
  RouteResult? driverApproachRoute;
  LatLng? driverPosition;
  int etaMinutes = 0;
  BookingStatus tripStatus = BookingStatus.searching;
  bool simulationMode = false;

  Timer? _simTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingSub;
  // The driver's start -> pickup route is fetched once, the first time the
  // live row carries the driver's start position.
  bool _approachRequested = false;

  // ---- Activity tab ----
  List<Booking> pastBookings = [];
  List<CarServiceRequest> pastServiceRequests = [];

  bool get isDraftComplete => pickup != null && destination != null;

  void setPickup(LatLng point, String address) {
    pickup = point;
    pickupAddress = address;
    notifyListeners();
    _recalculate();
  }

  void setDestination(LatLng point, String address) {
    destination = point;
    destAddress = address;
    notifyListeners();
    _recalculate();
  }

  void setTier(ServiceTier value) {
    tier = value;
    if (tripRoute != null) _applyFare(const []);
    notifyListeners();
  }

  void setPaymentLabel(String label) {
    paymentLabel = label;
    notifyListeners();
  }

  void setVehicle(Vehicle vehicle) {
    selectedVehicle = vehicle;
    notifyListeners();
  }

  // Fetch the OSRM route and recompute the fare whenever the trip changes.
  Future<void> _recalculate({List<WeatherAlert> alerts = const []}) async {
    if (pickup == null || destination == null) return;
    routeLoading = true;
    notifyListeners();

    tripRoute = await _routing.route(pickup!, destination!);
    _applyFare(alerts);

    routeLoading = false;
    notifyListeners();
  }

  // Public entry so screens can pass the current weather alerts in for the
  // wet-weather surcharge.
  Future<void> recalculateWithAlerts(List<WeatherAlert> alerts) {
    return _recalculate(alerts: alerts);
  }

  void _applyFare(List<WeatherAlert> alerts) {
    if (tripRoute == null) return;
    fare = FareCalculator.calculate(
      tier: tier,
      route: tripRoute!,
      activeAlerts: alerts,
    );
  }

  // Create the (unassigned) booking row, take payment and write a receipt.
  Future<Booking?> confirmAndPay() async {
    final userId = _userId;
    if (userId == null ||
        pickup == null ||
        destination == null ||
        fare == null) {
      return null;
    }

    // Cancel any earlier still-searching booking by this user first, so there
    // is never more than one live request (e.g. after the app was killed
    // mid-search, or a cancel that did not persist).
    try {
      await supabase
          .from('bookings')
          .update({'status': BookingStatus.cancelled.name})
          .eq('user_id', userId)
          .eq('status', BookingStatus.searching.name);
    } catch (e) {
      print('confirmAndPay cleanup error: $e');
    }

    final draft = Booking(
      id: 'pending',
      userId: userId,
      driverId: null,
      pickupLat: pickup!.latitude,
      pickupLng: pickup!.longitude,
      pickupAddress: pickupAddress,
      destLat: destination!.latitude,
      destLng: destination!.longitude,
      destAddress: destAddress,
      serviceTier: tier,
      fareEstimate: fare!.total,
      paymentMethod: paymentLabel,
      paymentStatus: 'paid',
      vehicleId: selectedVehicle?.id,
      status: BookingStatus.searching,
      createdAt: DateTime.now(),
    );

    try {
      final inserted =
          await supabase.from('bookings').insert(draft.toMap()).select();
      final booking =
          Booking.fromJson((inserted as List).first as Map<String, dynamic>);

      await _writeReceipt(
        bookingId: booking.id,
        amount: fare!.total,
        description: '${tier.label} booking · ${booking.routeLabel}',
      );

      activeBooking = booking;
      activeDriver = null;
      driverPosition = null;
      driverApproachRoute = null;
      _approachRequested = false;
      simulationMode = false;
      tripStatus = BookingStatus.searching;
      pastBookings = [booking, ...pastBookings];
      notifyListeners();
      return booking;
    } catch (e) {
      print('confirmAndPay error: $e');
      return null;
    }
  }

  // Open a still-in-progress trip from Activity or the Home "last trip" card
  // (rather than the normal confirmAndPay -> Searching -> Trip Tracking
  // flow). Hydrates the driver/route/live-position state Trip Tracking needs
  // from the row itself, then follows it live the same way, so e.g. a
  // driver's force-complete is reflected immediately instead of the screen
  // showing a one-time snapshot.
  Future<void> resumeTrip(Booking booking) async {
    simulationMode = false;
    _approachRequested = false;
    await _syncFromRow(booking);
    subscribeToActiveBooking();
  }

  // Watch the booking row live. When a real driver accepts it, sync the driver
  // + status + live position from the row (unless the simulation already owns
  // the trip).
  void subscribeToActiveBooking() {
    final booking = activeBooking;
    if (booking == null) return;

    _bookingSub?.cancel();
    _bookingSub = supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', booking.id)
        .listen((rows) {
          if (rows.isEmpty || simulationMode) return;
          _syncFromRow(Booking.fromJson(rows.first));
        });
  }

  // Apply a live booking-row update from a real driver: their position, the
  // driver profile, and the two route legs the map needs -
  //   driverApproachRoute : driver's start -> pickup  (shown while enRoute)
  //   tripRoute           : pickup -> destination     (shown throughout)
  Future<void> _syncFromRow(Booking updated) async {
    activeBooking = updated;
    tripStatus = updated.status;

    if (updated.driverLat != null && updated.driverLng != null) {
      driverPosition = LatLng(updated.driverLat!, updated.driverLng!);
    }
    if (updated.driverId != null && activeDriver == null) {
      _loadDriverProfile(updated.driverId!);
    }

    final pickupPoint = LatLng(updated.pickupLat, updated.pickupLng);
    final destPoint = LatLng(updated.destLat, updated.destLng);

    tripRoute ??= await _routing.route(pickupPoint, destPoint);

    if (!_approachRequested &&
        updated.driverStartLat != null &&
        updated.driverStartLng != null) {
      _approachRequested = true;
      driverApproachRoute = await _routing.route(
        LatLng(updated.driverStartLat!, updated.driverStartLng!),
        pickupPoint,
      );
    }

    // Rough ETA from whichever leg is being driven now.
    if (tripStatus == BookingStatus.onTrip) {
      etaMinutes = (tripRoute?.durationMinutes ?? 0).clamp(1, 90);
    } else if (tripStatus == BookingStatus.enRoute) {
      etaMinutes = (driverApproachRoute?.durationMinutes ?? 0).clamp(1, 60);
    }

    notifyListeners();
  }

  Future<void> _loadDriverProfile(String driverId) async {
    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', driverId)
          .maybeSingle();
      if (row != null) {
        activeDriver = Driver.fromProfile(Profile.fromJson(row));
        notifyListeners();
      }
    } catch (e) {
      print('_loadDriverProfile error: $e');
    }
  }

  // No real driver accepted in time - run the trip locally so the demo works.
  Future<void> runSimulationFallback() async {
    final booking = activeBooking;
    if (booking == null || simulationMode) return;
    // A real driver already picked it up - let the live row drive the trip.
    if (activeDriver != null ||
        booking.driverId != null ||
        tripStatus != BookingStatus.searching) {
      return;
    }
    simulationMode = true;

    final pickupPoint = LatLng(booking.pickupLat, booking.pickupLng);
    final destPoint = LatLng(booking.destLat, booking.destLng);
    final driverStart = LatLng(
      booking.pickupLat + 0.012,
      booking.pickupLng + 0.010,
    );
    driverApproachRoute = await _routing.route(driverStart, pickupPoint);
    tripRoute ??= await _routing.route(pickupPoint, destPoint);

    activeDriver = Driver(
      id: 'sim-driver',
      name: 'Razif Hakim',
      rating: 4.9,
      verified: true,
      trips: 1204,
    );

    tripStatus = BookingStatus.enRoute;
    _updateStatus(BookingStatus.enRoute);

    final path = <LatLng>[
      ...?driverApproachRoute?.points,
      ...?tripRoute?.points,
    ];
    final arriveIndex = driverApproachRoute?.points.length ?? 0;
    int i = 0;

    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (i >= path.length) {
        timer.cancel();
        // Parked at the destination - wait for the passenger to tap "Confirm
        // trip completed" (confirmTripCompleted below) rather than
        // auto-completing, same rule as a real driver's trip.
        tripStatus = BookingStatus.arrived;
        _updateStatus(BookingStatus.arrived);
        notifyListeners();
        return;
      }
      driverPosition = path[i];
      final remaining = path.length - i;
      etaMinutes = (remaining * 0.12).ceil().clamp(1, 40);

      if (i == arriveIndex && tripStatus == BookingStatus.enRoute) {
        tripStatus = BookingStatus.onTrip;
        _updateStatus(BookingStatus.onTrip);
      }
      i++;
      notifyListeners();
    });
  }

  Future<void> _updateStatus(BookingStatus status) async {
    final booking = activeBooking;
    if (booking == null) return;
    try {
      await supabase
          .from('bookings')
          .update({'status': status.name}).eq('id', booking.id);
    } catch (e) {
      print('_updateStatus error: $e');
    }
  }

  // reason is required once a driver has been matched (enRoute or later) -
  // the trip was already paid for at that point, so cancelling needs an
  // explanation on the record, same as a driver's forceCompleteJob. It's
  // optional while still searching, since no driver has committed to the
  // trip yet.
  Future<void> cancelActiveBooking({String? reason}) async {
    _simTimer?.cancel();
    await _bookingSub?.cancel();
    _bookingSub = null;
    final booking = activeBooking;
    if (booking != null) {
      try {
        final update = <String, dynamic>{'status': BookingStatus.cancelled.name};
        if (reason != null && reason.trim().isNotEmpty) {
          update['cancellation_reason'] = reason.trim();
        }
        final rows = await supabase
            .from('bookings')
            .update(update)
            .eq('id', booking.id)
            .select();
        if ((rows as List).isEmpty) {
          print('cancelActiveBooking: row not updated (RLS?) id=${booking.id}');
        }
        // Keep the Activity list in sync so the cancelled trip shows there.
        pastBookings = pastBookings
            .map((b) => b.id == booking.id
                ? b.copyWith(
                    status: BookingStatus.cancelled,
                    cancellationReason: reason,
                  )
                : b)
            .toList();
      } catch (e) {
        print('cancelActiveBooking error: $e');
      }
    }
    activeBooking = null;
    activeDriver = null;
    driverPosition = null;
    driverApproachRoute = null;
    _approachRequested = false;
    simulationMode = false;
    tripStatus = BookingStatus.searching;
    notifyListeners();
  }

  // Called from Trip Tracking when the driver has reported 'arrived' and the
  // passenger taps "Confirm trip completed". This - not the driver - is what
  // normally closes out a trip, so a driver alone can't mark a trip done
  // without the passenger's say-so (a driver who genuinely can't get that
  // confirmation, e.g. an intoxicated passenger, uses the separate
  // DriverProvider.forceCompleteJob path instead, which requires a reason).
  Future<void> confirmTripCompleted() async {
    final booking = activeBooking;
    if (booking == null || tripStatus != BookingStatus.arrived) return;
    tripStatus = BookingStatus.completed;
    activeBooking = booking.copyWith(
      status: BookingStatus.completed,
      completedBy: 'passenger',
    );
    notifyListeners();
    try {
      await supabase.from('bookings').update({
        'status': BookingStatus.completed.name,
        'completed_by': 'passenger',
      }).eq('id', booking.id);
    } catch (e) {
      print('confirmTripCompleted error: $e');
    }
  }

  // Called from Trip Tracking once the trip is completed - clears the active
  // trip and refreshes the Activity list so it shows the final status.
  Future<void> finishActiveTrip() async {
    _simTimer?.cancel();
    await _bookingSub?.cancel();
    _bookingSub = null;
    activeBooking = null;
    activeDriver = null;
    driverPosition = null;
    driverApproachRoute = null;
    _approachRequested = false;
    simulationMode = false;
    tripStatus = BookingStatus.searching;
    notifyListeners();
    await loadActivity();
  }

  // Swap the active trip's route for the safer alternative (Module 2).
  void applySafeRoute(RouteResult safeRoute) {
    tripRoute = safeRoute;
    notifyListeners();
  }

  void clearDraft() {
    pickup = null;
    destination = null;
    pickupAddress = '';
    destAddress = '';
    tripRoute = null;
    fare = null;
    notifyListeners();
  }

  Future<void> _writeReceipt({
    required String bookingId,
    required double amount,
    required String description,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase.from('receipts').insert(
            Receipt(
              id: 'pending',
              userId: userId,
              bookingId: bookingId,
              amount: amount,
              description: description,
              createdAt: DateTime.now(),
            ).toMap(),
          );
    } catch (e) {
      print('_writeReceipt error: $e');
    }
  }

  Future<void> loadActivity() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      // A booking's user_id is the passenger and driver_id is whoever drove
      // it, so this one query covers both: a passenger's own trips, or (for a
      // driver account) the trips they drove for someone else.
      final bookingRows = await supabase
          .from('bookings')
          .select()
          .or('user_id.eq.$userId,driver_id.eq.$userId')
          .order('created_at', ascending: false);
      pastBookings = (bookingRows as List)
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();

      final serviceRows = await supabase
          .from('car_service_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      pastServiceRequests = (serviceRows as List)
          .map((json) =>
              CarServiceRequest.fromJson(json as Map<String, dynamic>))
          .toList();

      notifyListeners();
    } catch (e) {
      print('loadActivity error: $e');
    }
  }

  void clear() {
    _simTimer?.cancel();
    _bookingSub?.cancel();
    activeBooking = null;
    activeDriver = null;
    simulationMode = false;
    pastBookings = [];
    pastServiceRequests = [];
    clearDraft();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _bookingSub?.cancel();
    super.dispose();
  }
}
