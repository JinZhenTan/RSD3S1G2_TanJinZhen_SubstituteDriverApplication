import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/routing_service.dart';
import '../../../supabase_config.dart';
import '../../../models/booking.dart';
import '../../../models/route_result.dart';
import '../../../models/vehicle.dart';

// State for the 'driver' role. A driver sees unassigned trip requests, accepts
// one, and moves it through the status steps. Once accepted, the driver's
// real device GPS (via geolocator) is streamed and written to driver_lat /
// driver_lng on the row so the passenger's Trip Tracking screen follows the
// actual car - there is no scripted/simulated movement here.
class DriverProvider extends ChangeNotifier {
  final _routing = RoutingService();

  String? get _userId => supabase.auth.currentUser?.id;

  List<Booking> availableJobs = [];
  Booking? activeJob;
  RouteResult? activeRoute; // pickup -> destination (the trip itself)
  RouteResult? approachRoute; // driver's start -> pickup ("coming to you")
  LatLng? driverPosition; // where the driver marker currently is
  // The passenger's own car for the active job - the driver needs to know
  // which car to look for and whether it is auto / manual.
  Vehicle? activeJobVehicle;
  bool isLoading = false;

  // Set once when the passenger changes the active job's row from outside
  // this app - cancelling it, or confirming completion while this driver was
  // still on the 'arrived' waiting screen. The driver's screens watch this to
  // show a one-time notice, then call acknowledgeJobNotice() to clear it.
  Booking? jobEndedByPassenger;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<Map<String, dynamic>>>? _jobsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _activeJobSub;

  // ---- Earnings (Profile > Earnings) ----
  // The basic salary and platform deduction rate are per-driver columns on
  // profiles (profiles.basic_salary / earnings_deduction_rate), not fixed
  // constants - the caller (EarningsScreen) passes them in from the signed-in
  // driver's profile row.
  DateTime earningsMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Booking> monthlyTrips = [];
  bool earningsLoading = false;

  List<Booking> get completedMonthlyTrips =>
      monthlyTrips.where((b) => b.status == BookingStatus.completed).toList();

  double get tripEarnings => completedMonthlyTrips.fold(
        0.0,
        (sum, b) => sum + (b.fareFinal ?? b.fareEstimate),
      );

  double earningsDeductions(double deductionRate) => tripEarnings * deductionRate;

  double netPay(double basicSalary, double deductionRate) =>
      basicSalary + tripEarnings - earningsDeductions(deductionRate);

  bool get canShowNextMonth {
    final now = DateTime.now();
    return earningsMonth.year < now.year ||
        (earningsMonth.year == now.year && earningsMonth.month < now.month);
  }

  // Load every trip this driver drove in the given month (any status, so a
  // cancelled trip still shows in the history even though it earns nothing).
  Future<void> loadEarningsForMonth(DateTime month) async {
    final userId = _userId;
    if (userId == null) return;
    earningsMonth = DateTime(month.year, month.month);
    earningsLoading = true;
    notifyListeners();

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    try {
      final rows = await supabase
          .from('bookings')
          .select()
          .eq('driver_id', userId)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);
      monthlyTrips = (rows as List)
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('DriverProvider.loadEarningsForMonth error: $e');
    } finally {
      earningsLoading = false;
      notifyListeners();
    }
  }

  void showPreviousEarningsMonth() {
    loadEarningsForMonth(DateTime(earningsMonth.year, earningsMonth.month - 1));
  }

  void showNextEarningsMonth() {
    if (!canShowNextMonth) return;
    loadEarningsForMonth(DateTime(earningsMonth.year, earningsMonth.month + 1));
  }

  // Live list of unassigned trip requests so new bookings appear immediately.
  //
  // We deliberately stream the recent bookings WITHOUT a server-side
  // `status = searching` filter and filter in Dart instead: a realtime stream
  // filtered by status never delivers the update that moves a row OUT of the
  // filter, so a cancelled or just-accepted booking would otherwise linger in
  // the list.
  void watchAvailableJobs() {
    _jobsSub?.cancel();
    _jobsSub = supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(40)
        .listen((rows) {
          availableJobs = rows
              .map(Booking.fromJson)
              .where((b) =>
                  b.status == BookingStatus.searching && b.driverId == null)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          notifyListeners();
        });
  }

  // Load the specific car the passenger picked for this trip (null if they
  // never added one). Falls back to their default/first vehicle for older
  // rows saved before per-trip vehicle selection existed (no vehicle_id).
  // RLS lets any signed-in account read a vehicle row.
  Future<void> _loadJobVehicle(String passengerId, {String? vehicleId}) async {
    try {
      final query = supabase.from('vehicles').select().eq('user_id', passengerId);
      final row = vehicleId != null
          ? await query.eq('id', vehicleId).maybeSingle()
          : await query.order('is_default', ascending: false).limit(1).maybeSingle();
      activeJobVehicle = row == null ? null : Vehicle.fromJson(row);
      notifyListeners();
    } catch (e) {
      print('DriverProvider._loadJobVehicle error: $e');
    }
  }

  Future<void> loadJobs() async {
    final userId = _userId;
    if (userId == null) return;
    isLoading = true;
    notifyListeners();

    try {
      final availableRows = await supabase
          .from('bookings')
          .select()
          .isFilter('driver_id', null)
          .eq('status', 'searching')
          .order('created_at', ascending: false);
      availableJobs = (availableRows as List)
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();

      final mineRows = await supabase
          .from('bookings')
          .select()
          .eq('driver_id', userId)
          .inFilter('status', ['enRoute', 'onTrip', 'arrived'])
          .order('created_at', ascending: false)
          .limit(1);
      final mine = mineRows as List;
      activeJob = mine.isEmpty
          ? null
          : Booking.fromJson(mine.first as Map<String, dynamic>);

      if (activeJob != null) {
        final pickup = LatLng(activeJob!.pickupLat, activeJob!.pickupLng);
        final dest = LatLng(activeJob!.destLat, activeJob!.destLng);
        activeRoute = await _routing.route(pickup, dest);
        if (activeJob!.driverStartLat != null &&
            activeJob!.driverStartLng != null) {
          approachRoute = await _routing.route(
            LatLng(activeJob!.driverStartLat!, activeJob!.driverStartLng!),
            pickup,
          );
        }
        if (activeJob!.driverLat != null && activeJob!.driverLng != null) {
          driverPosition =
              LatLng(activeJob!.driverLat!, activeJob!.driverLng!);
        }
        await _loadJobVehicle(activeJob!.userId, vehicleId: activeJob!.vehicleId);
        // Not once 'arrived' - the car is parked, waiting on the passenger.
        if (activeJob!.status != BookingStatus.arrived) {
          _startLocationUpdates();
        }
        _subscribeActiveJob(activeJob!.id);
      } else {
        activeJobVehicle = null;
      }
    } catch (e) {
      print('DriverProvider.loadJobs error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Try to claim a job. Returns false if another driver got it first.
  //
  // manualStart lets the driver tap their own starting point on the request
  // card's map instead of using device GPS - meant for presenting/demoing
  // the app (e.g. on a laptop or an emulator sitting on its default
  // location), where real GPS wouldn't be anywhere near the pickup. When
  // set, live GPS tracking is skipped entirely for this job so the chosen
  // point isn't immediately overwritten by the device's real position.
  Future<bool> acceptJob(Booking booking, {LatLng? manualStart}) async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      final updated = await supabase
          .from('bookings')
          .update({'driver_id': userId, 'status': BookingStatus.enRoute.name})
          .eq('id', booking.id)
          .isFilter('driver_id', null)
          .select();
      if ((updated as List).isEmpty) return false;

      activeJob = Booking.fromJson(updated.first);
      availableJobs.removeWhere((j) => j.id == booking.id);

      final pickup = LatLng(activeJob!.pickupLat, activeJob!.pickupLng);
      final dest = LatLng(activeJob!.destLat, activeJob!.destLng);

      // Where the driver is right now - the trip starts with them driving to
      // the passenger, not from the pickup point.
      final start = manualStart ?? await _resolveDriverStart(pickup);
      driverPosition = start;

      // Persist the start so the passenger's Trip Tracking screen can draw the
      // "driver coming to you" route, and seed the live position.
      try {
        await supabase.from('bookings').update({
          'driver_start_lat': start.latitude,
          'driver_start_lng': start.longitude,
          'driver_lat': start.latitude,
          'driver_lng': start.longitude,
        }).eq('id', activeJob!.id);
        activeJob = activeJob!.copyWith(
          driverStartLat: start.latitude,
          driverStartLng: start.longitude,
          driverLat: start.latitude,
          driverLng: start.longitude,
        );
      } catch (e) {
        print('DriverProvider.acceptJob start-write error: $e');
      }

      approachRoute = await _routing.route(start, pickup);
      activeRoute = await _routing.route(pickup, dest);
      await _loadJobVehicle(activeJob!.userId);
      notifyListeners();
      if (manualStart == null) _startLocationUpdates();
      _subscribeActiveJob(activeJob!.id);
      return true;
    } catch (e) {
      print('DriverProvider.acceptJob error: $e');
      return false;
    }
  }

  // enRoute -> onTrip -> arrived. Completion itself is deliberately NOT
  // reachable from here: only the passenger's confirmTripCompleted() (via
  // BookingProvider) or this driver's own forceCompleteJob(reason) below can
  // move a trip to completed, so a driver alone can never close out a trip.
  Future<void> setJobStatus(BookingStatus status) async {
    final job = activeJob;
    if (job == null) return;
    assert(status != BookingStatus.completed,
        'use forceCompleteJob() so a reason is always recorded');
    try {
      await supabase
          .from('bookings')
          .update({'status': status.name}).eq('id', job.id);
      activeJob = job.copyWith(status: status);
      if (status == BookingStatus.arrived) {
        // Parked at the destination - stop pushing position updates and wait
        // for the passenger to confirm from their Trip Tracking screen.
        _positionSub?.cancel();
      }
      notifyListeners();
    } catch (e) {
      print('DriverProvider.setJobStatus error: $e');
    }
  }

  // Fallback for when the passenger genuinely cannot tap "Confirm trip
  // completed" themselves (e.g. intoxicated or asleep - the most common
  // reason someone books a substitute driver in the first place). A reason is
  // required and stored on the row (completion_note) so the closure is
  // auditable rather than a driver silently ending the trip on their own.
  Future<bool> forceCompleteJob(String reason) async {
    final job = activeJob;
    if (job == null || reason.trim().isEmpty) return false;
    try {
      await supabase.from('bookings').update({
        'status': BookingStatus.completed.name,
        'completed_by': 'driver',
        'completion_note': reason.trim(),
      }).eq('id', job.id);
      _clearActiveJob();
      notifyListeners();
      return true;
    } catch (e) {
      print('DriverProvider.forceCompleteJob error: $e');
      return false;
    }
  }

  void _clearActiveJob() {
    _positionSub?.cancel();
    _activeJobSub?.cancel();
    activeJob = null;
    activeRoute = null;
    approachRoute = null;
    driverPosition = null;
    activeJobVehicle = null;
  }

  // Follows the active job's row live so this driver finds out immediately
  // if the passenger ends it from their side - cancelling it, or confirming
  // completion while this driver was still waiting on the 'arrived' screen.
  // Started once a job is accepted (or resumed from a fresh app launch).
  void _subscribeActiveJob(String jobId) {
    _activeJobSub?.cancel();
    _activeJobSub = supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .listen((rows) {
      if (rows.isEmpty || activeJob == null) return;
      final updated = Booking.fromJson(rows.first);
      final endedByPassenger = updated.status == BookingStatus.cancelled ||
          (updated.status == BookingStatus.completed &&
              updated.completedBy == 'passenger');
      if (endedByPassenger) {
        jobEndedByPassenger = updated;
        _clearActiveJob();
      } else {
        activeJob = updated;
      }
      notifyListeners();
    });
  }

  // Dismisses the one-time "passenger ended this job" notice once the driver
  // has seen it.
  void acknowledgeJobNotice() {
    jobEndedByPassenger = null;
    notifyListeners();
  }

  // True if location services are on and permission is granted (requesting it
  // if not yet asked). Shared by _resolveDriverStart (one-off, at accept) and
  // _startLocationUpdates (continuous, for the rest of the trip).
  Future<bool> _hasLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      print('DriverProvider._hasLocationPermission error: $e');
      return false;
    }
  }

  // Resolve where the driver is when they accept a job. Uses the device's real
  // GPS when it is plausibly near the pickup; otherwise (permission denied, or
  // an emulator sitting on its default location on another continent) it
  // synthesises a believable point ~1.5 km away so the demo still shows the
  // driver driving in to meet the passenger.
  Future<LatLng> _resolveDriverStart(LatLng pickup) async {
    try {
      if (await _hasLocationPermission()) {
        final pos = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 8));
        final here = LatLng(pos.latitude, pos.longitude);
        const distance = Distance();
        if (distance.as(LengthUnit.Kilometer, here, pickup) <= 60) {
          return here;
        }
      }
    } catch (e) {
      print('DriverProvider._resolveDriverStart error: $e');
    }
    return LatLng(pickup.latitude + 0.014, pickup.longitude + 0.011);
  }

  // Stream the driver's real GPS position for the rest of the trip and push
  // it to driver_lat / driver_lng so the passenger's map follows the actual
  // car - not a scripted walk along the route line. Stops itself once the
  // trip is arrived/completed (see setJobStatus / _clearActiveJob).
  //
  // If location permission/service isn't available, driverPosition simply
  // stays at wherever acceptJob resolved it to - documented limitation for
  // the assignment rather than a fallback fake walk.
  Future<void> _startLocationUpdates() async {
    _positionSub?.cancel();
    if (!await _hasLocationPermission()) {
      print('DriverProvider: no location permission, live tracking disabled');
      return;
    }
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // metres moved before another update is emitted
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      print('DriverProvider position stream error: $e');
    });
  }

  Future<void> _onPosition(Position pos) async {
    final job = activeJob;
    if (job == null) {
      _positionSub?.cancel();
      return;
    }
    final point = LatLng(pos.latitude, pos.longitude);
    driverPosition = point;
    notifyListeners();

    try {
      await supabase.from('bookings').update({
        'driver_lat': point.latitude,
        'driver_lng': point.longitude,
      }).eq('id', job.id);
    } catch (e) {
      print('driver location update error: $e');
    }
  }

  void clear() {
    _positionSub?.cancel();
    _activeJobSub?.cancel();
    _jobsSub?.cancel();
    _jobsSub = null;
    availableJobs = [];
    activeJob = null;
    activeRoute = null;
    approachRoute = null;
    driverPosition = null;
    activeJobVehicle = null;
    jobEndedByPassenger = null;
    earningsMonth = DateTime(DateTime.now().year, DateTime.now().month);
    monthlyTrips = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _activeJobSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }
}
