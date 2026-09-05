import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../providers/service_staff_provider.dart';
import 'service_centre_screen.dart';
import 'service_pickup_screen.dart';
import 'service_return_screen.dart';

enum StaffStage { pickup, service, returnTrip }

extension on StaffStage {
  String get title {
    switch (this) {
      case StaffStage.pickup:
        return 'Pickup';
      case StaffStage.service:
        return 'Service';
      case StaffStage.returnTrip:
        return 'Return';
    }
  }

  String get emptyMessage {
    switch (this) {
      case StaffStage.pickup:
        return 'No pick-ups right now. Pull to refresh.';
      case StaffStage.service:
        return 'No cars at the centre right now.';
      case StaffStage.returnTrip:
        return 'No cars ready to send back right now.';
    }
  }
}

bool _inStage(CarServiceRequest r, StaffStage stage, String? userId) {
  final mine = r.driverId == userId;
  switch (stage) {
    case StaffStage.pickup:
      if (r.status == CarServiceStatus.requested) {
        return r.driverId == null;
      }
      if (!mine) return false;
      if (r.status == CarServiceStatus.cancelled) return r.pickedUpAt == null;
      return r.status == CarServiceStatus.assigned ||
          r.status == CarServiceStatus.pickedUp;
    case StaffStage.service:
      if (!mine) return false;
      if (r.status == CarServiceStatus.cancelled) {
        return r.pickedUpAt != null && r.returningAt == null;
      }
      return r.status == CarServiceStatus.atCentre;
    case StaffStage.returnTrip:
      if (!mine) return false;
      if (r.status == CarServiceStatus.cancelled) {
        return r.returningAt != null;
      }
      return r.status == CarServiceStatus.returning ||
          r.status == CarServiceStatus.returned;
  }
}

class ServiceStageListScreen extends StatelessWidget {
  const ServiceStageListScreen({super.key, required this.stage});

  final StaffStage stage;

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final userId = staff.currentUserId;
    final requests =
        staff.requests.where((r) => _inStage(r, stage, userId)).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => staff.loadRequests(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ScreenHeader(eyebrow: 'CAR SERVICE PARTNER', title: stage.title),
            const SizedBox(height: 12),
            if (staff.isLoading && requests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Center(
                  child: Tr(stage.emptyMessage,
                      style: const TextStyle(color: AppColors.muted)),
                ),
              ),
            ...requests.map((r) => _StageCard(stage: stage, request: r)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatefulWidget {
  const _StageCard({required this.stage, required this.request});

  final StaffStage stage;
  final CarServiceRequest request;

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    final staff = context.read<ServiceStaffProvider>();
    setState(() => _accepting = true);
    final ok = await staff.acceptRequest(widget.request);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ServicePickupScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That request was already taken.')),
      );
      staff.loadRequests();
    }
  }

  void _open(BuildContext context) {
    context.read<ServiceStaffProvider>().selectRequest(widget.request);
    final screen = switch (widget.stage) {
      StaffStage.pickup => const ServicePickupScreen(),
      StaffStage.service => const ServiceCentreScreen(),
      StaffStage.returnTrip => const ServiceReturnScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final isMine = r.driverId != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: InkWell(
        onTap: isMine ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Tr(
                    r.serviceTypesLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (isMine)
                  Text(
                    carServiceStatusLabel(r.status, forStaff: true),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr('Pick up')} '
              '${DateFormat('EEE, d MMM · h:mm a').format(r.pickupDatetime)}\n'
              '${r.pickupAddress}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.tr('Note')}: ${r.notes}',
                style: const TextStyle(fontSize: 11, color: AppColors.blue700),
              ),
            ],
            if (r.pickupLat != null && r.pickupLng != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MapView(
                  centre: LatLng(r.pickupLat!, r.pickupLng!),
                  markers: [
                    MapView.dot(
                        LatLng(r.pickupLat!, r.pickupLng!), AppColors.ok),
                  ],
                  height: 100,
                  zoom: 13,
                  interactive: false,
                ),
              ),
              const SizedBox(height: 6),
              const MapLegend(items: [MapLegendItem(AppColors.ok, 'Owner')]),
            ],
            const SizedBox(height: 12),
            if (isMine)
              Row(
                children: [
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.blue600),
                  const SizedBox(width: 4),
                  Tr('Open',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue600,
                      )),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _accepting ? null : _accept,
                  child: _accepting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Tr('Accept request'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
