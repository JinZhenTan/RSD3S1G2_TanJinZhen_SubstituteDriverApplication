import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/tr.dart';
import '../../../core/widgets/unread_dot.dart';
import '../../../models/car_service_request.dart';
import '../../../models/service_photo.dart';
import '../../../models/service_task.dart';
import '../../../models/vehicle.dart';
import '../../booking/screens/activity_chat_screen.dart';
import '../providers/service_staff_provider.dart';

// Shared building blocks for the two service-staff job screens
// (ServicePickupScreen and ServiceCentreScreen) - a job's map, customer,
// vehicle, centre and pickup-details cards, the photo strip, task row, and
// status step row all look the same on both pages, so they live here once.

Widget sectionTitle(String text) =>
    Tr(text, style: AppStyles.mono.copyWith(fontSize: 9.5));

// ---- map -------------------------------------------------------------
class JobMap extends StatelessWidget {
  const JobMap({super.key, required this.staff, required this.request});

  final ServiceStaffProvider staff;
  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final centre = staff.activeCentre;
    final hasPickup = request.pickupLat != null && request.pickupLng != null;
    if (!hasPickup && centre == null) return const SizedBox.shrink();

    final pickup = hasPickup
        ? LatLng(request.pickupLat!, request.pickupLng!)
        : centre!.latLng;
    final staffPos = staff.staffPosition;

    final phase = request.status;
    final goingToPickup = phase == CarServiceStatus.assigned;
    final goingToCentre = phase == CarServiceStatus.pickedUp;
    // Covers both actually driving back and already having arrived - the
    // route leg to draw is the same either way (centre -> owner).
    final onReturnLeg = phase == CarServiceStatus.returning ||
        phase == CarServiceStatus.returned;

    List<LatLng> mainRoute;
    List<LatLng> approach;
    if (goingToPickup) {
      approach = staff.approachRoute?.points ?? const [];
      mainRoute = staff.toCentreRoute?.points ?? const [];
    } else if (goingToCentre) {
      approach = const [];
      mainRoute = staff.toCentreRoute?.points ?? const [];
    } else if (onReturnLeg) {
      approach = const [];
      mainRoute = staff.returnRoute?.points ?? const [];
    } else {
      approach = const [];
      mainRoute = staff.toCentreRoute?.points ?? const [];
    }

    final markers = <Marker>[
      MapView.dot(pickup, AppColors.ok),
      if (centre != null)
        MapView.pin(centre.latLng, AppColors.blue700,
            icon: Icons.home_repair_service),
      if (staffPos != null)
        MapView.pin(staffPos, AppColors.blue600, icon: Icons.local_shipping),
    ];

    final fallbackTarget =
        goingToPickup || onReturnLeg ? pickup : (centre?.latLng ?? pickup);

    return Column(
      children: [
        MapView(
          centre: staffPos ?? pickup,
          routePoints:
              mainRoute.isEmpty ? [pickup, fallbackTarget] : mainRoute,
          driverRoutePoints: approach,
          markers: markers,
          height: 200,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: MapLegend(items: [
            const MapLegendItem(AppColors.ok, 'Owner'),
            if (centre != null)
              const MapLegendItem(AppColors.blue700, 'Service centre'),
            if (staffPos != null) const MapLegendItem(AppColors.blue600, 'You'),
          ]),
        ),
      ],
    );
  }
}

// ---- customer -------------------------------------------------------
class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.staff, required this.request});

  final ServiceStaffProvider staff;
  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final name = staff.activeCustomer?.name ?? 'Car owner';
    final phone = staff.activeCustomer?.phone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: AppColors.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone == null || phone.isEmpty
                      ? null
                      : () => Launcher.call(phone),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Tr('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActivityChatScreen(
                            serviceRequestId: request.id,
                            title: request.serviceTypesLabel,
                            driverName: name,
                            mySenderType: 'driver',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Tr('Message'),
                    ),
                    Positioned(
                      top: 6,
                      right: 10,
                      child: UnreadDot(
                        serviceRequestId: request.id,
                        mySenderType: 'driver',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone == null || phone.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Tr(
                'Owner has no phone number on file — use chat.',
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- vehicle -------------------------------------------------------
class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.car});

  final Vehicle? car;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined,
                  size: 16, color: AppColors.heroAccent),
              const SizedBox(width: 8),
              Tr('The car to collect',
                  style: AppStyles.eyebrow.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 8),
          if (car == null)
            const Tr(
              'The owner has not added their car details — confirm the plate '
              'and gearbox with them at pick-up.',
              style: TextStyle(color: AppColors.heroSubtext, fontSize: 11.5),
            )
          else ...[
            Text(
              '${car!.model} · ${car!.colour}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  car!.plateNumber,
                  style: const TextStyle(
                    color: AppColors.heroAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Text(' · ',
                    style: TextStyle(color: AppColors.heroSubtext)),
                Tr(
                  car!.transmission,
                  style: const TextStyle(
                    color: AppColors.heroSubtext,
                    fontSize: 12,
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

// ---- service centre ----------------------------------------------
class CentreCard extends StatelessWidget {
  const CentreCard({super.key, required this.staff});

  final ServiceStaffProvider staff;

  @override
  Widget build(BuildContext context) {
    final c = staff.activeCentre;
    if (c == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_repair_service_outlined,
                  size: 16, color: AppColors.blue700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Launcher.call(c.phone),
                icon: const Icon(Icons.call, size: 18, color: AppColors.blue600),
              ),
            ],
          ),
          Text(
            c.address,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            c.openingHours,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ---- pickup details --------------------------------------------
class PickupCard extends StatelessWidget {
  const PickupCard({super.key, required this.request});

  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr('Pick-up')}: ${request.pickupAddress}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            DateFormat('EEE, d MMM · h:mm a').format(request.pickupDatetime),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr('Note')}: ${request.notes}',
              style: const TextStyle(fontSize: 11, color: AppColors.blue700),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- generic label/value row (used for "estimated ready" on the centre
// screen) --------------------------------------------------------------
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
    this.icon = Icons.schedule,
  });

  final String label;
  final String? value;
  final VoidCallback? onEdit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppStyles.card,
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.blue600),
            const SizedBox(width: 10),
            Expanded(
              child: Tr(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            if (onEdit != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.edit_outlined,
                    size: 15, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- photo strip ---------------------------------------------
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.label,
    required this.photos,
    required this.onAdd,
  });

  final String label;
  final List<ServicePhoto> photos;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tr(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 66,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in photos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      p.imageUrl,
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 66,
                        height: 66,
                        color: AppColors.line,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 18, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              if (onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.blue100),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.blue600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- task row ----------------------------------------------
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.editable = true,
  });

  final ServiceTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;
  // False once the service work is done (car is on its way back / returned) -
  // the checklist stays visible for reference but is no longer tickable.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final declined = task.approval == TaskApproval.declined;
    final pending = task.approval == TaskApproval.pending;
    return Opacity(
      opacity: declined ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: AppStyles.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isDone,
              onChanged: !editable || declined || pending
                  ? null
                  : (v) => onToggle(v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (task.isExtra) ...[
                          const SizedBox(width: 6),
                          _badge(
                            pending
                                ? 'PENDING'
                                : declined
                                    ? 'DECLINED'
                                    : 'EXTRA',
                            pending
                                ? AppColors.warn
                                : declined
                                    ? AppColors.danger
                                    : AppColors.ok,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (task.detail != null && task.detail!.isNotEmpty)
                    Text(
                      task.detail!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.muted),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                task.price == 0
                    ? '—'
                    : 'RM ${task.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue700,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 15, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
}

// ---- shared step row (also used by the owner's tracker) --------------
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.ok
        : active
            ? AppColors.blue600
            : AppColors.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              done ? Icons.check : Icons.circle,
              size: done ? 13 : 7,
              color: done || active ? Colors.white : AppColors.muted,
            ),
          ),
          const SizedBox(width: 10),
          Tr(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: (done || active) ? AppColors.ink : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
