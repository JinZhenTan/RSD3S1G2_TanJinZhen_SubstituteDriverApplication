import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../core/widgets/unread_dot.dart';
import '../../../models/car_service_request.dart';
import '../../../models/service_photo.dart';
import '../../../models/service_task.dart';
import '../../booking/screens/activity_chat_screen.dart';
import '../providers/car_service_provider.dart';
import 'review_pay_screen.dart';

class StatusTrackerScreen extends StatefulWidget {
  const StatusTrackerScreen({super.key});

  @override
  State<StatusTrackerScreen> createState() => _StatusTrackerScreenState();
}

class _StatusTrackerScreenState extends State<StatusTrackerScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CarServiceProvider>().subscribeToActiveRequest();
  }

  @override
  void dispose() {
    context.read<CarServiceProvider>().unsubscribeActiveRequest();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarServiceProvider>();
    final r = state.active;

    if (r == null) {
      return const Scaffold(
        body: Center(child: Tr('No car-service request selected')),
      );
    }

    if (r.isCancelled) {
      return Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            ScreenHeader(
              eyebrow: 'VEHICLE CARE',
              title: 'Pick-up status',
              onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 18, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
              child: _CancelledCard(request: r),
            ),
          ],
        ),
      );
    }

    final steps = carServiceTrackableSteps;
    final currentStep = r.stepIndex;
    final isReturned = r.status == CarServiceStatus.returned;
    final pending = state.pendingApprovals;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => state.loadRequests(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ScreenHeader(
              eyebrow: 'VEHICLE CARE',
              title: 'Pick-up status',
              onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 18, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrackerMap(state: state, request: r),
                  const SizedBox(height: 8),
                  MapLegend(items: [
                    const MapLegendItem(AppColors.ok, 'Your car'),
                    if (state.activeCentre != null)
                      const MapLegendItem(AppColors.blue700, 'Service centre'),
                    if (state.staffPosition != null)
                      const MapLegendItem(AppColors.blue600, 'Service partner'),
                  ]),
                  const SizedBox(height: 16),

                  if (pending.isNotEmpty) ...[
                    _ApprovalCard(state: state, pending: pending),
                    const SizedBox(height: 16),
                  ],

                  for (var i = 0; i < steps.length; i++)
                    _Step(
                      label: carServiceStatusLabel(steps[i]),
                      detail: _detailFor(steps[i], r),
                      done: i < currentStep,
                      active: i == currentStep,
                      isLast: i == steps.length - 1,
                    ),
                  const SizedBox(height: 4),

                  _StaffCard(state: state, request: r),
                  const SizedBox(height: 12),
                  _CentreCard(state: state),
                  const SizedBox(height: 16),

                  if (state.tasks.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Tr('WHAT WE\'RE DOING',
                            style: AppStyles.mono.copyWith(fontSize: 9.5)),
                        Text(
                          '${state.tasks.where((t) => t.isDone).length}'
                          '/${state.tasks.where((t) => t.approval != TaskApproval.declined).length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...state.tasks.map((t) => _TaskLine(task: t)),
                    const SizedBox(height: 16),
                  ],

                  _PhotoGallery(photos: state.photos),

                  _CostBox(state: state, request: r),
                  const SizedBox(height: 14),

                  if (isReturned && r.paymentStatus != 'paid')
                    PrimaryButton(
                      label: 'Review & pay',
                      icon: Icons.arrow_forward,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReviewPayScreen(),
                        ),
                      ),
                    ),

                  if (r.driverId == null && r.status != CarServiceStatus.returned)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GhostButton(
                        label: 'Advance status (demo)',
                        onPressed: () =>
                            context.read<CarServiceProvider>().advanceStatus(),
                      ),
                    ),

                  if (state.canCancel)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextButton(
                        onPressed: () => _cancelRequest(context),
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Tr('Cancel request'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRequest(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Cancel this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tr(
              'Let us know why - this is kept on the request for the '
              'service partner.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. No longer need the service today',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tr('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Tr('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;
    await context.read<CarServiceProvider>().cancelRequest(reason);
  }

  String? _detailFor(CarServiceStatus step, CarServiceRequest r) {
    String? at(DateTime? d) =>
        d == null ? null : DateFormat('EEE d MMM · h:mm a').format(d);
    switch (step) {
      case CarServiceStatus.requested:
        return at(r.createdAt);
      case CarServiceStatus.assigned:
        return at(r.assignedAt) ??
            'A service partner will collect your car at '
                '${DateFormat('h:mm a').format(r.pickupDatetime)}.';
      case CarServiceStatus.pickedUp:
        return at(r.pickedUpAt) ??
            'Car collected from ${r.pickupAddress}.';
      case CarServiceStatus.atCentre:
        final base = at(r.atCentreAt) ?? 'Servicing in progress.';
        if (r.readyBy != null && r.status == CarServiceStatus.atCentre) {
          return '$base\nEstimated ready: '
              '${DateFormat('EEE d MMM · h:mm a').format(r.readyBy!)}';
        }
        return base;
      case CarServiceStatus.returning:
        return at(r.returningAt) ??
            'Your car is on its way back to ${r.pickupAddress}.';
      case CarServiceStatus.returned:
        return at(r.returnedAt) ??
            'Car dropped back at ${r.pickupAddress} — review and pay.';
      case CarServiceStatus.cancelled:
        return null;
    }
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.request});

  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
              SizedBox(width: 8),
              Tr(
                'This request was cancelled',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (request.cancellationReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${request.cancellationReason}',
              style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${request.serviceTypesLabel} · ${request.pickupAddress}',
            style: const TextStyle(color: AppColors.danger, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TrackerMap extends StatelessWidget {
  const _TrackerMap({required this.state, required this.request});

  final CarServiceProvider state;
  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final centre = state.activeCentre;
    final hasPickup = request.pickupLat != null && request.pickupLng != null;
    if (!hasPickup && centre == null) return const SizedBox.shrink();

    final pickup = hasPickup
        ? LatLng(request.pickupLat!, request.pickupLng!)
        : centre!.latLng;
    final staffPos = state.staffPosition;
    final phase = request.status;

    final goingToPickup = phase == CarServiceStatus.assigned;
    final onReturnLeg = phase == CarServiceStatus.returning ||
        phase == CarServiceStatus.returned;

    final approach =
        goingToPickup ? (state.staffApproachRoute?.points ?? const []) : const <LatLng>[];
    final mainRoute = onReturnLeg
        ? state.returnRoutePoints
        : (state.centreRoute?.points ?? const <LatLng>[]);

    final markers = <Marker>[
      MapView.dot(pickup, AppColors.ok),
      if (centre != null)
        MapView.pin(centre.latLng, AppColors.blue700,
            icon: Icons.home_repair_service),
      if (staffPos != null)
        MapView.pin(staffPos, AppColors.blue600, icon: Icons.local_shipping),
    ];

    return MapView(
      centre: staffPos ?? pickup,
      routePoints: mainRoute.isEmpty
          ? [pickup, centre?.latLng ?? pickup]
          : mainRoute,
      driverRoutePoints: approach,
      markers: markers,
      height: 180,
      interactive: true,
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.state, required this.pending});

  final CarServiceProvider state;
  final List<ServiceTask> pending;

  @override
  Widget build(BuildContext context) {
    final extra = pending.fold<double>(0, (s, t) => s + t.price);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D8A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_outlined,
                  size: 18, color: AppColors.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Tr(
                  'Extra work needs your approval',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Tr(
            'Your car isn\'t at the original estimate. Approve only what you '
            'want done — declined items are skipped and not billed.',
            style: const TextStyle(fontSize: 11, color: AppColors.warn),
          ),
          const SizedBox(height: 10),
          for (final t in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          'RM ${t.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.blue700,
                          ),
                        ),
                      ],
                    ),
                    if (t.detail != null && t.detail!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          t.detail!,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.muted),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                state.respondToExtra(t, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Tr('Decline'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                state.respondToExtra(t, true),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Tr('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Tr(
            'Total extra if you approve all: RM ${extra.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.warn,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.state, required this.request});

  final CarServiceProvider state;
  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final staff = state.activeStaff;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: staff == null
                ? const Icon(Icons.engineering_outlined,
                    color: AppColors.blue600)
                : Text(
                    staff.initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.blue700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff?.name ?? 'Assigning a service partner…',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const Tr(
                  'Vehicle care team',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (staff != null) ...[
            IconButton(
              onPressed: staff.phone == null || staff.phone!.isEmpty
                  ? null
                  : () => Launcher.call(staff.phone!),
              icon: const Icon(Icons.call, color: AppColors.blue600),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActivityChatScreen(
                        serviceRequestId: request.id,
                        title: request.serviceTypesLabel,
                        driverName: staff.name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: AppColors.blue600),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: UnreadDot(
                    serviceRequestId: request.id,
                    mySenderType: 'user',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({required this.state});

  final CarServiceProvider state;

  @override
  Widget build(BuildContext context) {
    final c = state.activeCentre;
    if (c == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Row(
        children: [
          const Icon(Icons.home_repair_service_outlined,
              size: 18, color: AppColors.blue700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '${c.address}\n${c.openingHours}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Launcher.call(c.phone),
            icon: const Icon(Icons.call, color: AppColors.blue600),
          ),
        ],
      ),
    );
  }
}

class _TaskLine extends StatelessWidget {
  const _TaskLine({required this.task});

  final ServiceTask task;

  @override
  Widget build(BuildContext context) {
    final declined = task.approval == TaskApproval.declined;
    final pending = task.approval == TaskApproval.pending;
    return Opacity(
      opacity: declined ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              declined
                  ? Icons.remove_circle_outline
                  : task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
              size: 18,
              color: declined
                  ? AppColors.muted
                  : task.isDone
                      ? AppColors.ok
                      : AppColors.line,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            decoration:
                                declined ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warn.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEEDS APPROVAL',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warn,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (task.isDone && task.doneAt != null)
                    Text(
                      'Done ${DateFormat('d MMM, h:mm a').format(task.doneAt!)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted),
                    )
                  else if (task.detail != null && task.detail!.isNotEmpty)
                    Text(
                      task.detail!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            Text(
              task.price == 0 ? '—' : 'RM ${task.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.blue700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos});

  final List<ServicePhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final groups = <ServicePhotoPhase, List<ServicePhoto>>{};
    for (final p in photos) {
      groups.putIfAbsent(p.phase, () => []).add(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tr('PHOTOS', style: AppStyles.mono.copyWith(fontSize: 9.5)),
        const SizedBox(height: 8),
        for (final entry in groups.entries) ...[
          Text(
            servicePhotoPhaseLabel(entry.key),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entry.value.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final url = entry.value[i].imageUrl;
                return GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      child: InteractiveViewer(
                        child: Image.network(url),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: AppColors.line,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 18, color: AppColors.muted),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CostBox extends StatelessWidget {
  const _CostBox({required this.state, required this.request});

  final CarServiceProvider state;
  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final isReturned = r.status == CarServiceStatus.returned;
    final liveTotal =
        state.billableTotal > 0 ? state.billableTotal : (r.finalCost ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tr(
                isReturned ? 'Final service cost' : 'Running total',
                style: const TextStyle(color: Color(0xFF9AACC9), fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                isReturned || liveTotal > 0
                    ? 'RM ${liveTotal.toStringAsFixed(2)}'
                    : r.estimateLabel,
                style: const TextStyle(
                  color: AppColors.heroAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              if (!isReturned)
                Tr(
                  'Estimate ${r.estimateLabel}',
                  style: const TextStyle(
                      color: Color(0xFF9AACC9), fontSize: 10),
                ),
            ],
          ),
          if (r.paymentStatus == 'paid')
            const Tr(
              'PAID',
              style: TextStyle(
                color: AppColors.ok,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.detail,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final String label;
  final String? detail;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? AppColors.ok
        : active
            ? AppColors.blue600
            : AppColors.line;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check : Icons.circle,
                  size: done ? 15 : 8,
                  color: done || active ? Colors.white : AppColors.muted,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.ok : AppColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          (done || active) ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
