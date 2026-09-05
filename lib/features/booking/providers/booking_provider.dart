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

class BookingProvider extends ChangeNotifier {
  final _routing = RoutingService();

  String? get _userId => supabase.auth.currentUser?.id;

  LatLng? pickup;
  String pickupAddress = '';
  LatLng? destination;
  String destAddress = '';
  ServiceTier tier = ServiceTier.standard;
  String paymentLabel = 'Cash';
  Vehicle? selectedVehicle;

  RouteResult? tripRoute;
  FareBreakdown? fare;
  bool routeLoading = false;

  Booking? activeBooking;
  Driver? activeDriver;
  RouteResult? driverApproachRoute;
  LatLng? driverPosition;
  int etaMinutes = 0;
  BookingStatus tripStatus = BookingStatus.searching;
  bool simulationMode = false;

  Timer? _simTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingSub;
  bool _approachRequested = false;

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

  Future<void> _recalculate({List<WeatherAlert> alerts = const []}) async {
    if (pickup == null || destination == null) return;
    routeLoading = true;
    notifyListeners();

    tripRoute = await _routing.route(pickup!, destination!);
    _applyFare(alerts);

    routeLoading = false;
    notifyListeners();
  }

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

  Future<Booking?> confirmAndPay() async {
    final userId = _userId;
    if (userId == null ||
        pickup == null ||
        destination == null ||
        fare == null) {
      return null;
    }

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

  Future<void> resumeTrip(Booking booking) async {
    simulationMode = false;
    _approachRequested = false;
    await _syncFromRow(booking);
    subscribeToActiveBooking();
  }

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

  Future<void> runSimulationFallback() async {
    final booking = activeBooking;
    if (booking == null || simulationMode) return;
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
