import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../core/widgets/unread_dot.dart';
import '../../../models/booking.dart';
import '../../../models/vehicle.dart';
import '../../booking/screens/activity_chat_screen.dart';
import '../providers/driver_provider.dart';

class DriverJobDetailScreen extends StatelessWidget {
  const DriverJobDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final job = driver.activeJob;
    final car = driver.activeJobVehicle;

    if (job == null) {
      final ended = driver.jobEndedByPassenger;
      if (ended != null) {
        final cancelled = ended.status == BookingStatus.cancelled;
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                    color: cancelled ? AppColors.danger : AppColors.ok,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Tr(
                    cancelled
                        ? 'This booking was cancelled by the passenger'
                        : 'The passenger confirmed this booking is complete',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                  if (cancelled && ended.cancellationReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${ended.cancellationReason}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Back to available bookings',
                    onPressed: () {
                      context.read<DriverProvider>().acknowledgeJobNotice();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: Tr('No active booking')));
    }

    final pickup = LatLng(job.pickupLat, job.pickupLng);
    final dest = LatLng(job.destLat, job.destLng);
    final driverPos = driver.driverPosition;
    final enRoute = job.status == BookingStatus.enRoute;

    final markers = <Marker>[
      if (enRoute) MapView.dot(pickup, AppColors.ok),
      MapView.pin(dest, AppColors.danger),
      if (driverPos != null)
        MapView.pin(
          driverPos,
          AppColors.blue600,
          icon: enRoute ? Icons.navigation : Icons.directions_car,
        ),
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            eyebrow: enRoute
                ? 'HEADING TO PICKUP'
                : (job.status == BookingStatus.arrived
                    ? 'AWAITING PASSENGER CONFIRMATION'
                    : 'DRIVING TO DESTINATION'),
            title: job.routeLabel,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
            child: Column(
              children: [
                MapView(
                  centre: driverPos ?? pickup,
                  routePoints: enRoute
                      ? (driver.approachRoute?.points ?? [driverPos ?? pickup, pickup])
                      : (driver.activeRoute?.points ?? [pickup, dest]),
                  driverRoutePoints: enRoute
                      ? (driver.activeRoute?.points ?? const [])
                      : const [],
                  markers: markers,
                  height: 220,
                ),
                const SizedBox(height: 8),
                MapLegend(items: [
                  if (enRoute) const MapLegendItem(AppColors.ok, 'Passenger'),
                  const MapLegendItem(AppColors.danger, 'Destination'),
                  if (driverPos != null)
                    const MapLegendItem(AppColors.blue600, 'You'),
                ]),
                const SizedBox(height: 14),
                _CarCard(car: car),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppStyles.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(context, 'Pick up', job.pickupAddress, AppColors.ok),
                      const Divider(height: 16, color: AppColors.line),
                      _row(context, 'Drop off', job.destAddress,
                          AppColors.danger),
                      const Divider(height: 16, color: AppColors.line),
                      _row(
                        context,
                        'Fare',
                        'RM ${job.fareEstimate.toStringAsFixed(2)} · '
                            '${job.paymentMethod}',
                        AppColors.blue600,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (job.status == BookingStatus.enRoute)
                  PrimaryButton(
                    label: 'Picked up passenger',
                    icon: Icons.arrow_forward,
                    onPressed: () => context
                        .read<DriverProvider>()
                        .setJobStatus(BookingStatus.onTrip),
                  )
                else if (job.status == BookingStatus.onTrip)
                  PrimaryButton(
                    label: 'Arrived at destination',
                    icon: Icons.flag_outlined,
                    onPressed: () => context
                        .read<DriverProvider>()
                        .setJobStatus(BookingStatus.arrived),
                  )
                else if (job.status == BookingStatus.arrived) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Tr(
                            'Waiting for the passenger to confirm the '
                            'booking is complete.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blue700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GhostButton(
                    label: 'Passenger unable to confirm',
                    onPressed: () => _forceComplete(context),
                  ),
                ],
                const SizedBox(height: 10),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GhostButton(
                      label: 'Message passenger',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActivityChatScreen(
                            bookingId: job.id,
                            title: job.routeLabel,
                            driverName: 'Passenger',
                            mySenderType: 'driver',
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 14,
                      child: UnreadDot(bookingId: job.id, mySenderType: 'driver'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _forceComplete(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Complete without passenger confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tr(
              'This ends the booking on your behalf. Explain why the '
              'passenger could not confirm it themselves - this is recorded '
              'on the booking for accountability.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Passenger is intoxicated and asleep',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Tr('Complete booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<DriverProvider>().forceCompleteJob(reason);
    if (!ok) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Booking completed and reason recorded.')),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color colour) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tr(label, style: AppStyles.mono.copyWith(fontSize: 9)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({required this.car});

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
              Tr(
                'The car you will be driving',
                style: AppStyles.eyebrow.copyWith(fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (car == null)
            const Tr(
              'The passenger has not added their car details yet - confirm '
              'the plate and gearbox with them at pick-up.',
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

