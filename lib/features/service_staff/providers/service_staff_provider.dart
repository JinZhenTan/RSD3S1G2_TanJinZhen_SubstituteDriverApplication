import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/services/routing_service.dart';
import '../../../supabase_config.dart';
import '../../../models/car_service_request.dart';
import '../../../models/profile.dart';
import '../../../models/route_result.dart';
import '../../../models/service_centre.dart';
import '../../../models/service_photo.dart';
import '../../../models/service_task.dart';
import '../../../models/vehicle.dart';

// State for the 'service_staff' role. A service partner sees unassigned car
// service requests, accepts one (choosing which service centre it goes to),
// drives to the owner's address, collects the car, works through the task
// checklist, and enters the final cost - which is the sum of the billable
// tasks, not a free-text guess.
//
// The staff's real device GPS (via geolocator) is streamed for the rest of
// the job and written to staff_lat / staff_lng so the owner's Status Tracker
// follows the actual vehicle - same fix as the substitute driver's tracking,
// no scripted/simulated movement.
class ServiceStaffProvider extends ChangeNotifier {
  static const String _photoBucket = 'service-photos';

  final _routing = RoutingService();

  String? get _userId => supabase.auth.currentUser?.id;
  // Public read-only access to the signed-in staff id - used by the stage
  // list screens to tell "mine" jobs apart from unassigned ones.
  String? get currentUserId => _userId;

  // ---- Feed ----
  List<CarServiceRequest> requests = [];
  bool isLoading = false;

  // ---- Seeded workshops ----
  List<ServiceCentre> serviceCentres = [];

  // ---- The job being worked ----
  CarServiceRequest? active;
  Vehicle? activeVehicle; // the owner's car
  Profile? activeCustomer; // the owner
  ServiceCentre? activeCentre;
  List<ServiceTask> tasks = [];
  List<ServicePhoto> photos = [];

  // ---- Live map ----
  LatLng? staffPosition;
  RouteResult? approachRoute; // staff start -> owner's address
  RouteResult? toCentreRoute; // owner's address -> service centre
  RouteResult? returnRoute; // service centre -> owner's address

  StreamSubscription<Position>? _positionSub;

  StreamSubscription<List<Map<String, dynamic>>>? _activeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<List<Map<String, dynamic>>>? _photosSub;
  StreamSubscription<List<Map<String, dynamic>>>? _feedSub;

  // ---- Earnings (Profile > Earnings) ----
  // Same idea as the driver role's Earnings screen: a basic salary + a share
  // of the jobs actually completed in the selected month, using the same
  // profiles.basic_salary / earnings_deduction_rate columns (not
  // driver-specific - any role can have them).
  DateTime earningsMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<CarServiceRequest> monthlyJobs = [];
  bool earningsLoading = false;

  List<CarServiceRequest> get completedMonthlyJobs => monthlyJobs
      .where((r) => r.status == CarServiceStatus.returned)
      .toList();

  double get jobEarnings => completedMonthlyJobs.fold(
        0.0,
        (sum, r) => sum + (r.finalCost ?? r.costEstimateMin.toDouble()),
      );

  double earningsDeductions(double deductionRate) => jobEarnings * deductionRate;

  double netPay(double basicSalary, double deductionRate) =>
      basicSalary + jobEarnings - earningsDeductions(deductionRate);

  bool get canShowNextMonth {
    final now = DateTime.now();
    return earningsMonth.year < now.year ||
        (earningsMonth.year == now.year && earningsMonth.month < now.month);
  }

  // Load every job this staff member worked in the given month (any status,
  // so a cancelled job still shows in the history even though it earns
  // nothing).
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
          .from('car_service_requests')
          .select()
          .eq('driver_id', userId)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);
      monthlyJobs = (rows as List)
          .map((json) => CarServiceRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('ServiceStaffProvider.loadEarningsForMonth error: $e');
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

  // ---- Derived --------------------------------------------------------------
  double get billableTotal =>
      tasks.where((t) => t.isBillable).fold(0.0, (s, t) => s + t.price);

  List<ServiceTask> get pendingApprovals =>
      tasks.where((t) => t.approval == TaskApproval.pending).toList();

  List<ServiceTask> get tasksBlockingReturn =>
      tasks.where((t) => t.blocksReturn).toList();

  int get tasksDone => tasks.where((t) => t.isDone).length;

  // Can the staff move the job to the next status step? Returns a reason string
  // when they cannot, so the screen can explain the hold-up.
  String? get advanceBlockedReason {
    final r = active;
    if (r == null) return 'No job selected';
    switch (r.status) {
      case CarServiceStatus.requested:
        return 'Accept the job first';
      case CarServiceStatus.assigned:
        if (!photos.any((p) => p.phase == ServicePhotoPhase.pickup)) {
          return 'Add at least one pick-up photo of the car';
        }
        return null;
      case CarServiceStatus.pickedUp:
        return null; // arriving at the centre
      case CarServiceStatus.atCentre:
        if (pendingApprovals.isNotEmpty) {
          return '${pendingApprovals.length} extra task(s) still waiting on the owner';
        }
        if (tasksBlockingReturn.isNotEmpty) {
          return '${tasksBlockingReturn.length} task(s) not ticked off yet';
        }
        return null; // ready to send the car back
      case CarServiceStatus.returning:
        if (!photos.any((p) => p.phase == ServicePhotoPhase.ret)) {
          return 'Add at least one return photo of the car';
        }
        return null;
      case CarServiceStatus.returned:
        return 'Job finished — waiting on payment';
      case CarServiceStatus.cancelled:
        return 'This request was cancelled';
    }
  }

  bool get canAdvance =>
      active != null &&
      active!.status != CarServiceStatus.returned &&
      advanceBlockedReason == null;

  // ---- Seeded data --------------------------------------------------------
  Future<void> loadServiceCentres() async {
    if (serviceCentres.isNotEmpty) return;
    try {
      final rows = await supabase.from('service_centres').select().order('name');
      serviceCentres = (rows as List)
          .map((j) => ServiceCentre.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.loadServiceCentres error: $e');
    }
  }

  // ---- Feed -------------------------------------------------------------
  void watchRequests() {
    _feedSub?.cancel();
    _feedSub = supabase
        .from('car_service_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) {
          final userId = _userId;
          requests = rows
              .map(CarServiceRequest.fromJson)
              // A cancelled-and-unassigned request has nothing for any staff
              // to accept, but a job already assigned to me stays visible
              // even if the owner then cancelled it, so I can see that.
              .where((r) =>
                  r.driverId == userId || (r.driverId == null && !r.isCancelled))
              .toList();
          // Keep the active job's row in sync if it is in the feed.
          if (active != null) {
            for (final r in requests) {
              if (r.id == active!.id) active = r;
            }
          }
          notifyListeners();
        });
  }

  Future<void> loadRequests() async {
    final userId = _userId;
    if (userId == null) return;
    isLoading = true;
    notifyListeners();

    try {
      final unassigned = await supabase
          .from('car_service_requests')
          .select()
          .isFilter('driver_id', null)
          .neq('status', CarServiceStatus.cancelled.name)
          .order('created_at', ascending: false);
      final mine = await supabase
          .from('car_service_requests')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false);

      requests = [
        ...(mine as List).map(
          (j) => CarServiceRequest.fromJson(j as Map<String, dynamic>),
        ),
        ...(unassigned as List).map(
          (j) => CarServiceRequest.fromJson(j as Map<String, dynamic>),
        ),
      ];
    } catch (e) {
      print('ServiceStaffProvider.loadRequests error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ---- Open a job -----------------------------------------------------
  void selectRequest(CarServiceRequest request) {
    active = request;
    activeVehicle = null;
    activeCustomer = null;
    activeCentre = null;
    tasks = [];
    photos = [];
    approachRoute = null;
    toCentreRoute = null;
    returnRoute = null;
    staffPosition = (request.staffLat != null && request.staffLng != null)
        ? LatLng(request.staffLat!, request.staffLng!)
        : null;
    notifyListeners();
  }

  // Called by the detail screen: follow the row + tasks + photos live, load the
  // owner / car / centre, rebuild the map legs, and resume real GPS tracking
  // if this job is mine and already in progress.
  Future<void> subscribeToActive() async {
    final request = active;
    final userId = _userId;
    if (request == null) return;

    _subscribeActiveRow();
    _subscribeTasks();
    _subscribePhotos();

    await Future.wait([
      _loadCustomer(request.userId),
      _loadVehicle(request),
      _loadCentre(request.serviceCentreId),
    ]);
    await _rebuildRoutes(request);

    if (request.driverId == userId &&
        request.status != CarServiceStatus.requested &&
        request.status != CarServiceStatus.returned) {
      _startLocationUpdates();
    }
    notifyListeners();
  }

  void unsubscribeActive() {
    _activeSub?.cancel();
    _tasksSub?.cancel();
    _photosSub?.cancel();
    _activeSub = null;
    _tasksSub = null;
    _photosSub = null;
    _positionSub?.cancel();
  }

  void _subscribeActiveRow() {
    final request = active;
    if (request == null) return;
    _activeSub?.cancel();
    _activeSub = supabase
        .from('car_service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', request.id)
        .listen((rows) {
          if (rows.isEmpty) return;
          final updated = CarServiceRequest.fromJson(rows.first);
          final centreChanged =
              updated.serviceCentreId != active?.serviceCentreId;
          _replace(updated);
          active = updated;
          if (centreChanged) _loadCentre(updated.serviceCentreId);
          notifyListeners();
        });
  }

  void _subscribeTasks() {
    final request = active;
    if (request == null) return;
    _tasksSub?.cancel();
    _tasksSub = supabase
        .from('service_tasks')
        .stream(primaryKey: ['id'])
        .eq('service_request_id', request.id)
        .order('created_at')
        .listen((rows) {
          tasks = rows.map(ServiceTask.fromJson).toList();
          notifyListeners();
        });
  }

  void _subscribePhotos() {
    final request = active;
    if (request == null) return;
    _photosSub?.cancel();
    _photosSub = supabase
        .from('service_photos')
        .stream(primaryKey: ['id'])
        .eq('service_request_id', request.id)
        .order('created_at')
        .listen((rows) {
          photos = rows.map(ServicePhoto.fromJson).toList();
          notifyListeners();
        });
  }

  Future<void> _loadCustomer(String userId) async {
    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row != null) activeCustomer = Profile.fromJson(row);
    } catch (e) {
      print('ServiceStaffProvider._loadCustomer error: $e');
    }
  }

  Future<void> _loadVehicle(CarServiceRequest request) async {
    try {
      final row = request.vehicleId != null
          ? await supabase
              .from('vehicles')
              .select()
              .eq('id', request.vehicleId!)
              .maybeSingle()
          : await supabase
              .from('vehicles')
              .select()
              .eq('user_id', request.userId)
              .limit(1)
              .maybeSingle();
      activeVehicle = row == null ? null : Vehicle.fromJson(row);
    } catch (e) {
      print('ServiceStaffProvider._loadVehicle error: $e');
    }
  }

  Future<void> _loadCentre(String? centreId) async {
    if (centreId == null) {
      activeCentre = null;
      return;
    }
    await loadServiceCentres();
    ServiceCentre? match;
    for (final c in serviceCentres) {
      if (c.id == centreId) match = c;
    }
    activeCentre = match;
    notifyListeners();
  }

  // ---- Accept --------------------------------------------------------
  // There is only one physical service centre (TAR UMT Penang Branch), so
  // accepting a job no longer asks the staff to pick one - it's assigned
  // automatically, and the staff's starting position for the job is the
  // centre's own location (they set out from there), not a GPS guess.
  static const String fixedServiceCentreId = 'sc_tarumt';

  Future<bool> acceptRequest(CarServiceRequest request) async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      await loadServiceCentres();
      if (serviceCentres.isEmpty) return false;
      final centre = serviceCentres.firstWhere(
        (c) => c.id == fixedServiceCentreId,
        orElse: () => serviceCentres.first,
      );
      final start = centre.latLng;
      final now = DateTime.now().toUtc().toIso8601String();

      final updated = await supabase
          .from('car_service_requests')
          .update({
            'driver_id': userId,
            'status': CarServiceStatus.assigned.name,
            'service_centre_id': centre.id,
            'staff_lat': start.latitude,
            'staff_lng': start.longitude,
            'assigned_at': now,
          })
          .eq('id', request.id)
          .eq('status', CarServiceStatus.requested.name)
          .isFilter('driver_id', null)
          .select();
      if ((updated as List).isEmpty) return false;

      active = CarServiceRequest.fromJson(updated.first);
      _replace(active!);
      staffPosition = start;
      activeCentre = centre;

      await Future.wait([
        _loadCustomer(active!.userId),
        _loadVehicle(active!),
      ]);
      await _rebuildRoutes(active!);
      _subscribeActiveRow();
      _subscribeTasks();
      _subscribePhotos();
      _startLocationUpdates();
      notifyListeners();
      return true;
    } catch (e) {
      print('ServiceStaffProvider.acceptRequest error: $e');
      return false;
    }
  }

  // ---- Status steps -------------------------------------------------
  Future<void> advanceStatus() async {
    final request = active;
    if (request == null || !canAdvance) return;

    final lastStep = carServiceTrackableSteps.length - 1;
    if (request.stepIndex < 0 || request.stepIndex >= lastStep) return;
    final next = carServiceTrackableSteps[request.stepIndex + 1];

    final updates = <String, dynamic>{'status': next.name};
    final nowIso = DateTime.now().toUtc().toIso8601String();
    switch (next) {
      case CarServiceStatus.pickedUp:
        updates['picked_up_at'] = nowIso;
        break;
      case CarServiceStatus.atCentre:
        updates['at_centre_at'] = nowIso;
        break;
      case CarServiceStatus.returning:
        // The service work is done as of this step - lock in the final
        // cost here rather than waiting for the car to actually arrive back.
        updates['returning_at'] = nowIso;
        updates['final_cost'] = billableTotal;
        break;
      case CarServiceStatus.returned:
        updates['returned_at'] = nowIso;
        break;
      default:
        break;
    }

    try {
      await supabase
          .from('car_service_requests')
          .update(updates)
          .eq('id', request.id);
      final updated = request.copyWith(
        status: next,
        finalCost: updates['final_cost'] as double?,
        assignedAt: updates['assigned_at'] != null ? DateTime.now() : null,
        pickedUpAt: updates['picked_up_at'] != null ? DateTime.now() : null,
        atCentreAt: updates['at_centre_at'] != null ? DateTime.now() : null,
        returningAt: updates['returning_at'] != null ? DateTime.now() : null,
        returnedAt: updates['returned_at'] != null ? DateTime.now() : null,
      );
      _replace(updated);
      active = updated;
      if (next == CarServiceStatus.returned) _positionSub?.cancel();
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.advanceStatus error: $e');
    }
  }

  Future<void> setReadyBy(DateTime readyBy) async {
    final request = active;
    if (request == null) return;
    try {
      await supabase.from('car_service_requests').update({
        'ready_by': readyBy.toUtc().toIso8601String(),
      }).eq('id', request.id);
      final updated = request.copyWith(readyBy: readyBy);
      _replace(updated);
      active = updated;
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.setReadyBy error: $e');
    }
  }

  // ---- Tasks -------------------------------------------------------
  // Every write below applies to local state immediately rather than
  // waiting on the service_tasks realtime echo, which isn't always
  // delivered back to the same client that made the write - without this a
  // staff member's own screen could stay stuck showing the old state (e.g.
  // a ticked box the staff had just unticked snapping back, or a checklist
  // that still looked incomplete after a photo/task change actually saved).
  Future<void> toggleTask(ServiceTask task, bool done) async {
    try {
      await supabase.from('service_tasks').update({
        'is_done': done,
        'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', task.id);
      tasks = tasks
          .map((t) => t.id == task.id
              ? t.copyWith(isDone: done, clearDoneAt: !done)
              : t)
          .toList();
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.toggleTask error: $e');
    }
    await _recomputeFinalCost();
  }

  // Extra work found on inspection - starts 'pending' so the owner decides.
  Future<void> addExtraTask({
    required String title,
    String? detail,
    required double price,
  }) async {
    final request = active;
    if (request == null) return;
    try {
      final inserted = await supabase.from('service_tasks').insert({
        'service_request_id': request.id,
        'title': title,
        'detail': detail,
        'price': price,
        'is_extra': true,
        'approval': 'pending',
      }).select();
      final row = (inserted as List).first as Map<String, dynamic>;
      tasks = [...tasks, ServiceTask.fromJson(row)];
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.addExtraTask error: $e');
    }
  }

  Future<void> deleteTask(ServiceTask task) async {
    try {
      await supabase.from('service_tasks').delete().eq('id', task.id);
      tasks = tasks.where((t) => t.id != task.id).toList();
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider.deleteTask error: $e');
    }
    await _recomputeFinalCost();
  }

  // Keep car_service_requests.final_cost = sum of the billable tasks, so the
  // owner's Review & Pay screen always shows the live figure.
  Future<void> _recomputeFinalCost() async {
    final request = active;
    if (request == null) return;
    final total = billableTotal;
    try {
      await supabase
          .from('car_service_requests')
          .update({'final_cost': total})
          .eq('id', request.id);
      final updated = request.copyWith(finalCost: total);
      _replace(updated);
      active = updated;
      notifyListeners();
    } catch (e) {
      print('ServiceStaffProvider._recomputeFinalCost error: $e');
    }
  }

  // ---- Photos -----------------------------------------------------
  Future<bool> addPhoto({
    required ServicePhotoPhase phase,
    required Uint8List bytes,
    required String fileName,
    String? caption,
  }) async {
    final request = active;
    if (request == null || bytes.isEmpty) return false;
    try {
      final ext = _extensionOf(fileName);
      final objectPath =
          '${request.id}/${servicePhotoPhaseToName(phase)}_'
          '${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from(_photoBucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(contentType: _mimeFor(ext)),
          );
      final url = supabase.storage.from(_photoBucket).getPublicUrl(objectPath);
      final inserted = await supabase.from('service_photos').insert({
        'service_request_id': request.id,
        'phase': servicePhotoPhaseToName(phase),
        'image_url': url,
        'caption': caption,
      }).select();
      // Apply locally right away rather than waiting on the realtime echo,
      // which isn't always delivered back to the same client that wrote it -
      // this was leaving the staff's own screen still showing "no pick-up
      // photo yet" (and blocking advance) even after a successful upload,
      // while the owner's screen (a different client) saw it fine.
      final row = (inserted as List).first as Map<String, dynamic>;
      photos = [...photos, ServicePhoto.fromJson(row)];
      notifyListeners();
      return true;
    } catch (e) {
      print('ServiceStaffProvider.addPhoto error: $e');
      return false;
    }
  }

  // ---- Location walk --------------------------------------------
  LatLng _pickupOf(CarServiceRequest r) => LatLng(
        r.pickupLat ?? activeCentre?.lat ?? 3.139,
        r.pickupLng ?? activeCentre?.lng ?? 101.6869,
      );

  Future<void> _rebuildRoutes(CarServiceRequest r) async {
    final pickup = _pickupOf(r);
    final centre = activeCentre?.latLng;
    final start = staffPosition ?? pickup;

    approachRoute = await _routing.route(start, pickup);
    if (centre != null) {
      toCentreRoute = await _routing.route(pickup, centre);
      returnRoute = await _routing.route(centre, pickup);
    }
    notifyListeners();
  }

  // True if location services are on and permission is granted (requesting it
  // if not yet asked). Used by _startLocationUpdates once a job is accepted -
  // the starting position itself now just comes from the fixed service
  // centre (see acceptRequest), not GPS.
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
      print('ServiceStaffProvider._hasLocationPermission error: $e');
      return false;
    }
  }

  // Stream the staff's real GPS position for the rest of the job and push it
  // to staff_lat / staff_lng so the owner's map follows the actual vehicle -
  // not a scripted walk along the route line. Stops itself on 'returned' (see
  // advanceStatus). If location permission/service isn't available,
  // staffPosition simply stays at wherever acceptRequest resolved it to.
  Future<void> _startLocationUpdates() async {
    _positionSub?.cancel();
    if (!await _hasLocationPermission()) {
      print('ServiceStaffProvider: no location permission, live tracking disabled');
      return;
    }
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // metres moved before another update is emitted
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      print('ServiceStaffProvider position stream error: $e');
    });
  }

  Future<void> _onPosition(Position pos) async {
    final r = active;
    if (r == null) {
      _positionSub?.cancel();
      return;
    }
    final point = LatLng(pos.latitude, pos.longitude);
    staffPosition = point;
    notifyListeners();
    try {
      await supabase.from('car_service_requests').update({
        'staff_lat': point.latitude,
        'staff_lng': point.longitude,
      }).eq('id', r.id);
    } catch (e) {
      print('ServiceStaffProvider staff location update error: $e');
    }
  }

  // ---- helpers ---------------------------------------------------
  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    return ext == 'jpeg' ? 'jpg' : ext;
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  void _replace(CarServiceRequest updated) {
    requests = requests.map((r) => r.id == updated.id ? updated : r).toList();
  }

  void clear() {
    unsubscribeActive();
    _feedSub?.cancel();
    _feedSub = null;
    requests = [];
    active = null;
    activeVehicle = null;
    activeCustomer = null;
    activeCentre = null;
    tasks = [];
    photos = [];
    staffPosition = null;
    approachRoute = null;
    toCentreRoute = null;
    returnRoute = null;
    earningsMonth = DateTime(DateTime.now().year, DateTime.now().month);
    monthlyJobs = [];
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeActive();
    _feedSub?.cancel();
    super.dispose();
  }
}
