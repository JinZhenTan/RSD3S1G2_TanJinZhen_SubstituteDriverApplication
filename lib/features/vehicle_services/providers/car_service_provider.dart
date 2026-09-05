import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/routing_service.dart';
import '../../../supabase_config.dart';
import '../../../models/car_service_request.dart';
import '../../../models/profile.dart';
import '../../../models/receipt.dart';
import '../../../models/route_result.dart';
import '../../../models/service_centre.dart';
import '../../../models/service_photo.dart';
import '../../../models/service_task.dart';
import '../../../models/vehicle.dart';
import '../services/default_service_tasks.dart';

class CarServiceProvider extends ChangeNotifier {
  String? get _userId => supabase.auth.currentUser?.id;

  DateTime pickupDateTime = _defaultPickup();
  String pickupAddress = '';
  LatLng? pickupPoint;
  List<CarServiceType> serviceTypes = [CarServiceType.general];
  String notes = '';

  List<CarServiceRequest> requests = [];
  CarServiceRequest? active;
  bool isLoading = false;

  List<ServiceCentre> serviceCentres = [];
  ServiceCentre? activeCentre;
  Profile? activeStaff;
  List<ServiceTask> tasks = [];
  List<ServicePhoto> photos = [];

  final _routing = RoutingService();
  RouteResult? centreRoute;
  RouteResult? staffApproachRoute;
  LatLng? _staffStart;

  LatLng? get staffPosition {
    final r = active;
    if (r?.staffLat == null || r?.staffLng == null) return null;
    return LatLng(r!.staffLat!, r.staffLng!);
  }

  List<LatLng> get returnRoutePoints =>
      centreRoute == null ? const [] : centreRoute!.points.reversed.toList();

  StreamSubscription<List<Map<String, dynamic>>>? _activeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<List<Map<String, dynamic>>>? _photosSub;

  double get billableTotal =>
      tasks.where((t) => t.isBillable).fold(0.0, (s, t) => s + t.price);

  List<ServiceTask> get pendingApprovals =>
      tasks.where((t) => t.approval == TaskApproval.pending).toList();

  Future<void> loadServiceCentres() async {
    if (serviceCentres.isNotEmpty) return;
    try {
      final rows =
          await supabase.from('service_centres').select().order('name');
      serviceCentres = (rows as List)
          .map((j) => ServiceCentre.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      print('CarServiceProvider.loadServiceCentres error: $e');
    }
  }

  void subscribeToActiveRequest() {
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
          final staffChanged = updated.driverId != active?.driverId;
          _replace(updated);
          active = updated;
          if (updated.staffLat != null && _staffStart == null) {
            _staffStart = LatLng(updated.staffLat!, updated.staffLng!);
          }
          if (centreChanged) _loadCentre(updated.serviceCentreId);
          if (staffChanged) _loadStaff(updated.driverId);
          _ensureRoutes();
          notifyListeners();
        });

    _loadCentre(request.serviceCentreId);
    _loadStaff(request.driverId);

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

  void unsubscribeActiveRequest() {
    _activeSub?.cancel();
    _tasksSub?.cancel();
    _photosSub?.cancel();
    _activeSub = null;
    _tasksSub = null;
    _photosSub = null;
  }

  Future<void> _loadCentre(String? centreId) async {
    if (centreId == null) {
      activeCentre = null;
      notifyListeners();
      return;
    }
    await loadServiceCentres();
    ServiceCentre? match;
    for (final c in serviceCentres) {
      if (c.id == centreId) match = c;
    }
    activeCentre = match;
    notifyListeners();
    await _ensureRoutes();
  }

  Future<void> _ensureRoutes() async {
    final r = active;
    if (r == null || r.pickupLat == null || r.pickupLng == null) return;
    final pickup = LatLng(r.pickupLat!, r.pickupLng!);
    if (activeCentre != null && centreRoute == null) {
      centreRoute = await _routing.route(pickup, activeCentre!.latLng);
      notifyListeners();
    }
    if (_staffStart != null && staffApproachRoute == null) {
      staffApproachRoute = await _routing.route(_staffStart!, pickup);
      notifyListeners();
    }
  }

  Future<void> _loadStaff(String? staffId) async {
    if (staffId == null) {
      activeStaff = null;
      notifyListeners();
      return;
    }
    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', staffId)
          .maybeSingle();
      activeStaff = row == null ? null : Profile.fromJson(row);
      notifyListeners();
    } catch (e) {
      print('CarServiceProvider._loadStaff error: $e');
    }
  }

  Future<void> respondToExtra(ServiceTask task, bool approved) async {
    try {
      final newApproval = approved ? TaskApproval.approved : TaskApproval.declined;
      await supabase.from('service_tasks').update({
        'approval': newApproval.name,
      }).eq('id', task.id);
      tasks = tasks
          .map((t) => t.id == task.id ? t.copyWith(approval: newApproval) : t)
          .toList();
      notifyListeners();
      final request = active;
      if (request != null) {
        final newTotal =
            tasks.where((t) => t.isBillable).fold<double>(0, (s, t) => s + t.price);
        await supabase
            .from('car_service_requests')
            .update({'final_cost': newTotal}).eq('id', request.id);
        _replace(request.copyWith(finalCost: newTotal));
        notifyListeners();
      }
    } catch (e) {
      print('CarServiceProvider.respondToExtra error: $e');
    }
  }

  static DateTime _defaultPickup() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 10);
  }

  void setDateTime(DateTime value) {
    pickupDateTime = value;
    notifyListeners();
  }

  void setPickup(String address, [LatLng? point]) {
    pickupAddress = address;
    pickupPoint = point;
    notifyListeners();
  }

  void toggleServiceType(CarServiceType value) {
    final selected = serviceTypes.contains(value);
    if (selected && serviceTypes.length == 1) return;
    serviceTypes = selected
        ? serviceTypes.where((t) => t != value).toList()
        : [...serviceTypes, value];
    notifyListeners();
  }

  int get estimateMin => serviceTypes.fold(0, (s, t) => s + t.estimateMin);
  int get estimateMax => serviceTypes.fold(0, (s, t) => s + t.estimateMax);

  void setNotes(String value) {
    notes = value;
  }

  Future<CarServiceRequest?> submitRequest(Vehicle? vehicle) async {
    final userId = _userId;
    if (userId == null) return null;

    final draft = CarServiceRequest(
      id: 'pending',
      userId: userId,
      vehicleId: vehicle?.id,
      pickupDatetime: pickupDateTime,
      pickupAddress: pickupAddress,
      pickupLat: pickupPoint?.latitude,
      pickupLng: pickupPoint?.longitude,
      serviceTypes: serviceTypes,
      costEstimateMin: estimateMin,
      costEstimateMax: estimateMax,
      status: CarServiceStatus.requested,
      paymentStatus: 'pending',
      notes: notes.isEmpty ? null : notes,
      createdAt: DateTime.now(),
    );

    try {
      final inserted = await supabase
          .from('car_service_requests')
          .insert(draft.toMap())
          .select();
      final saved = CarServiceRequest.fromJson(
        (inserted as List).first as Map<String, dynamic>,
      );

      try {
        await supabase
            .from('service_tasks')
            .insert(defaultServiceTasks(saved.id, saved.serviceTypes));
      } catch (e) {
        print('submitRequest seed-tasks error: $e');
      }

      requests = [saved, ...requests];
      active = saved;
      tasks = [];
      photos = [];
      notifyListeners();
      return saved;
    } catch (e) {
      print('submitRequest error: $e');
      return null;
    }
  }

  Future<void> loadRequests() async {
    final userId = _userId;
    if (userId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final rows = await supabase
          .from('car_service_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      requests = (rows as List)
          .map((json) =>
              CarServiceRequest.fromJson(json as Map<String, dynamic>))
          .toList();
      active = requests.isEmpty ? null : requests.first;
    } catch (e) {
      print('loadRequests error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectRequest(CarServiceRequest request) {
    active = request;
    tasks = [];
    photos = [];
    activeCentre = null;
    activeStaff = null;
    centreRoute = null;
    staffApproachRoute = null;
    _staffStart = (request.staffLat != null && request.staffLng != null)
        ? LatLng(request.staffLat!, request.staffLng!)
        : null;
    notifyListeners();
  }

  Future<void> advanceStatus() async {
    final request = active;
    if (request == null) return;

    final lastStep = carServiceTrackableSteps.length - 1;
    if (request.stepIndex < 0 || request.stepIndex >= lastStep) return;
    final next = carServiceTrackableSteps[request.stepIndex + 1];

    final updates = <String, dynamic>{'status': next.name};
    final nowIso = DateTime.now().toUtc().toIso8601String();
    switch (next) {
      case CarServiceStatus.assigned:
        updates['assigned_at'] = nowIso;
        break;
      case CarServiceStatus.pickedUp:
        updates['picked_up_at'] = nowIso;
        break;
      case CarServiceStatus.atCentre:
        updates['at_centre_at'] = nowIso;
        break;
      case CarServiceStatus.returning:
        updates['returning_at'] = nowIso;
        break;
      case CarServiceStatus.returned:
        updates['returned_at'] = nowIso;
        break;
      default:
        break;
    }

    try {
      if (next == CarServiceStatus.returning) {
        for (final t in tasks) {
          final patch = <String, dynamic>{
            'is_done': true,
            'done_at': nowIso,
          };
          if (t.approval == TaskApproval.pending) patch['approval'] = 'approved';
          await supabase.from('service_tasks').update(patch).eq('id', t.id);
        }
        final billable = tasks
            .where((t) => t.approval != TaskApproval.declined)
            .fold<double>(0, (s, t) => s + t.price);
        updates['final_cost'] = billable > 0
            ? billable
            : _generateItemisedCost(request.serviceType)
                .values
                .fold<double>(0, (s, v) => s + v);
      }

      await supabase
          .from('car_service_requests')
          .update(updates)
          .eq('id', request.id);
      _replace(request.copyWith(
        status: next,
        finalCost: updates['final_cost'] as double?,
      ));
      notifyListeners();
    } catch (e) {
      print('advanceStatus error: $e');
    }
  }

  bool get canCancel {
    final r = active;
    return r != null &&
        (r.status == CarServiceStatus.requested ||
            r.status == CarServiceStatus.assigned);
  }

  Future<bool> cancelRequest(String reason) async {
    final request = active;
    if (request == null || !canCancel || reason.trim().isEmpty) return false;
    try {
      await supabase.from('car_service_requests').update({
        'status': CarServiceStatus.cancelled.name,
        'cancellation_reason': reason.trim(),
      }).eq('id', request.id);
      final updated = request.copyWith(
        status: CarServiceStatus.cancelled,
        cancellationReason: reason.trim(),
      );
      _replace(updated);
      notifyListeners();
      return true;
    } catch (e) {
      print('cancelRequest error: $e');
      return false;
    }
  }

  Map<String, double> itemisedFinalCost(CarServiceRequest request) {
    final billable = tasks.where((t) => t.isBillable).toList();
    if (billable.isNotEmpty) {
      return {for (final t in billable) t.title: _round(t.price)};
    }

    final real = request.itemisedCost;
    if (real != null) return real;

    final total = request.finalCost ??
        _generateItemisedCost(request.serviceType)
            .values
            .fold<double>(0, (s, v) => s + v);
    const transport = 25.0;
    const inspection = 20.0;
    final remaining = total - transport - inspection;
    final labour = remaining * 0.55;
    final parts = remaining - labour;
    return {
      'Labour': _round(labour),
      'Parts & consumables': _round(parts),
      'Inspection fee': inspection,
      'Pick-up & drop-off': transport,
    };
  }

  Map<String, double> _generateItemisedCost(CarServiceType type) {
    final mid = (type.estimateMin + type.estimateMax) / 2;
    final workTotal = _round(mid * 0.9) - 45;
    return {
      'Labour': _round(workTotal * 0.55),
      'Parts & consumables': _round(workTotal * 0.45),
      'Inspection fee': 20.0,
      'Pick-up & drop-off': 25.0,
    };
  }

  Future<void> payForService(
    CarServiceRequest request,
    String paymentLabel,
  ) async {
    final userId = _userId;
    if (userId == null) return;
    final taskTotal = billableTotal;
    final amount = request.finalCost ??
        (taskTotal > 0
            ? taskTotal
            : _generateItemisedCost(request.serviceType)
                .values
                .fold<double>(0, (s, v) => s + v));
    try {
      await supabase
          .from('car_service_requests')
          .update({'payment_status': 'paid'}).eq('id', request.id);

      await supabase.from('receipts').insert(
            Receipt(
              id: 'pending',
              userId: userId,
              serviceRequestId: request.id,
              amount: amount,
              description: 'Car service — ${request.serviceTypesLabel}',
              createdAt: DateTime.now(),
            ).toMap(),
          );

      _replace(request.copyWith(finalCost: amount, paymentStatus: 'paid'));
      notifyListeners();
    } catch (e) {
      print('payForService error: $e');
    }
  }

  void _replace(CarServiceRequest updated) {
    requests = requests
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    if (active?.id == updated.id) active = updated;
  }

  double _round(double value) => (value * 100).round() / 100;

  void resetDraft() {
    pickupDateTime = _defaultPickup();
    pickupAddress = '';
    pickupPoint = null;
    serviceTypes = [CarServiceType.general];
    notes = '';
  }

  void clear() {
    unsubscribeActiveRequest();
    requests = [];
    active = null;
    activeCentre = null;
    activeStaff = null;
    tasks = [];
    photos = [];
    centreRoute = null;
    staffApproachRoute = null;
    _staffStart = null;
    resetDraft();
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeActiveRequest();
    super.dispose();
  }
}
