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

class ServiceStaffProvider extends ChangeNotifier {
  static const String _photoBucket = 'service-photos';

  final _routing = RoutingService();

  String? get _userId => supabase.auth.currentUser?.id;
  String? get currentUserId => _userId;

  List<CarServiceRequest> requests = [];
  bool isLoading = false;

  List<ServiceCentre> serviceCentres = [];

  CarServiceRequest? active;
  Vehicle? activeVehicle;
  Profile? activeCustomer;
  ServiceCentre? activeCentre;
  List<ServiceTask> tasks = [];
  List<ServicePhoto> photos = [];

  LatLng? staffPosition;
  RouteResult? approachRoute;
  RouteResult? toCentreRoute;
  RouteResult? returnRoute;

  StreamSubscription<Position>? _positionSub;

  StreamSubscription<List<Map<String, dynamic>>>? _activeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<List<Map<String, dynamic>>>? _photosSub;
  StreamSubscription<List<Map<String, dynamic>>>? _feedSub;

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

  double get billableTotal =>
      tasks.where((t) => t.isBillable).fold(0.0, (s, t) => s + t.price);

  List<ServiceTask> get pendingApprovals =>
      tasks.where((t) => t.approval == TaskApproval.pending).toList();

  List<ServiceTask> get tasksBlockingReturn =>
      tasks.where((t) => t.blocksReturn).toList();

  int get tasksDone => tasks.where((t) => t.isDone).length;

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
        return null;
      case CarServiceStatus.atCentre:
        if (pendingApprovals.isNotEmpty) {
          return '${pendingApprovals.length} extra task(s) still waiting on the owner';
        }
        if (tasksBlockingReturn.isNotEmpty) {
          return '${tasksBlockingReturn.length} task(s) not ticked off yet';
        }
        return null;
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
              .where((r) =>
                  r.driverId == userId || (r.driverId == null && !r.isCancelled))
              .toList();
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
      final row = (inserted as List).first as Map<String, dynamic>;
      photos = [...photos, ServicePhoto.fromJson(row)];
      notifyListeners();
      return true;
    } catch (e) {
      print('ServiceStaffProvider.addPhoto error: $e');
      return false;
    }
  }

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

  Future<void> _startLocationUpdates() async {
    _positionSub?.cancel();
    if (!await _hasLocationPermission()) {
      print('ServiceStaffProvider: no location permission, live tracking disabled');
      return;
    }
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
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
