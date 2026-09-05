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
import '../../../core/widgets/weather_banner.dart';
import '../../../models/booking.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../providers/booking_provider.dart';
import 'activity_chat_screen.dart';

// Module 1 - Trip Tracking. Live driver location on an OSM map, ETA, the
// driver card with the verified badge, and the share-trip toggle. The shared
// weather banner appears above the map. In-trip requests to the driver go
// through the chat (Message) instead of preset quick-command chips - one
// real channel is enough.
class TripTrackingScreen extends StatelessWidget {
  const TripTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final weather = context.watch<WeatherProvider>();
    final b = booking.activeBooking;
    final driver = booking.activeDriver;

    if (b == null) {
      return const Scaffold(body: Center(child: Tr('No active booking')));
    }

    final pickup = LatLng(b.pickupLat, b.pickupLng);
    final dest = LatLng(b.destLat, b.destLng);
    // Once you and the driver have met (onTrip / arrived / completed) the map
    // is just the car and the destination - the pickup marker and the
    // "driver coming to you" line drop away.
    final met = booking.tripStatus == BookingStatus.onTrip ||
        booking.tripStatus == BookingStatus.arrived ||
        booking.tripStatus == BookingStatus.completed;
    final markers = <Marker>[
      if (!met) MapView.dot(pickup, AppColors.ok),
      MapView.pin(dest, AppColors.danger),
      if (booking.driverPosition != null)
        MapView.pin(
          booking.driverPosition!,
          AppColors.blue600,
          icon: met ? Icons.directions_car : Icons.navigation,
        ),
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            eyebrow: _statusLabel(booking.tripStatus),
            title: b.routeLabel,
            // A live booking is already under way - "back" should never
            // step back into the booking-creation screens (search/pay), it
            // should return to Home like Finish/Cancel already do.
            onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                if (weather.bannerAlert != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: WeatherBanner(alert: weather.bannerAlert),
                  ),
                  const SizedBox(height: 12),
                ],
                MapView(
                  centre: booking.driverPosition ?? pickup,
                  routePoints: booking.tripRoute?.points ?? [pickup, dest],
                  driverRoutePoints: met
                      ? const []
                      : (booking.driverApproachRoute?.points ?? const []),
                  markers: markers,
                  height: 240,
                  interactive: true,
                ),
                const SizedBox(height: 8),
                MapLegend(items: [
                  if (!met) const MapLegendItem(AppColors.ok, 'Your car'),
                  const MapLegendItem(AppColors.danger, 'Destination'),
                  if (booking.driverPosition != null)
                    const MapLegendItem(AppColors.blue600, 'Driver'),
                ]),
                const SizedBox(height: 14),
                _EtaStrip(minutes: booking.etaMinutes, status: booking.tripStatus),
                const SizedBox(height: 14),
                if (booking.tripStatus == BookingStatus.arrived) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      border: Border.all(color: AppColors.blue100),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Tr(
                      'Your driver says the booking has ended. Confirm below '
                      'so it can be closed - only you can do this.',
                      style: TextStyle(
                        color: AppColors.blue700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Confirm booking completed',
                    icon: Icons.check,
                    onPressed: () => context
                        .read<BookingProvider>()
                        .confirmTripCompleted(),
                  ),
                  const SizedBox(height: 14),
                ],
                if (booking.tripStatus == BookingStatus.completed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.okSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Tr(
                          'You have arrived. Thanks for riding with Ganti.',
                          style: TextStyle(
                            color: AppColors.ok,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        if (b.completedBy == 'driver') ...[
                          const SizedBox(height: 8),
                          Tr(
                            'Completed by your driver'
                            '${b.completionNote != null ? ' - "${b.completionNote}"' : ''}.',
                            style: const TextStyle(
                              color: AppColors.ok,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Finish',
                    icon: Icons.check,
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await context
                          .read<BookingProvider>()
                          .finishActiveTrip();
                      navigator.popUntil((r) => r.isFirst);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (driver != null) _DriverCard(driver: driver, booking: b),
                const SizedBox(height: 18),
                const _ShareTripRow(),
                // Cancelling is only offered before the driver has picked up
                // the car (enRoute) - once onTrip the car is already out on
                // the road with the driver, so this stops being a sensible
                // self-service action. The booking was already paid for at
                // Confirm & Pay, so a reason is required on the record.
                if (booking.tripStatus == BookingStatus.enRoute) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _cancelTrip(context),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Tr('Cancel booking'),
                  ),
                ],
                SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Cancel this booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tr(
              'You already paid for this booking and a driver is on the '
              'way. Let us know why you are cancelling - this is kept on '
              'the record.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Plans changed, driving myself after all',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tr('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Tr('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    final navigator = Navigator.of(context);
    await context.read<BookingProvider>().cancelActiveBooking(reason: reason);
    navigator.popUntil((r) => r.isFirst);
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.enRoute:
        return 'DRIVER EN ROUTE';
      case BookingStatus.onTrip:
        return 'DRIVING NOW';
      case BookingStatus.arrived:
        return 'CONFIRM BOOKING COMPLETED';
      case BookingStatus.completed:
        return 'BOOKING COMPLETED';
      default:
        return 'EN ROUTE';
    }
  }
}

class _EtaStrip extends StatelessWidget {
  const _EtaStrip({required this.minutes, required this.status});

  final int minutes;
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == BookingStatus.completed;
    final awaitingConfirm = status == BookingStatus.arrived;
    final String eyebrow;
    final String value;
    if (done) {
      eyebrow = 'ARRIVED';
      value = context.tr('Done');
    } else if (awaitingConfirm) {
      eyebrow = 'ARRIVED';
      value = context.tr('Awaiting confirmation');
    } else if (status == BookingStatus.onTrip) {
      eyebrow = 'ARRIVING IN';
      value = '$minutes min';
    } else {
      eyebrow = 'DRIVER ARRIVES IN';
      value = '$minutes min';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        border: Border.all(color: AppColors.blue100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tr(
                eyebrow,
                style: AppStyles.mono.copyWith(
                  fontSize: 10,
                  color: AppColors.blue700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.blue700,
                  fontWeight: FontWeight.w700,
                  fontSize: awaitingConfirm ? 15 : 21,
                ),
              ),
            ],
          ),
          const Icon(Icons.directions_car, color: AppColors.blue700),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver, required this.booking});

  final dynamic driver;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5C6C8C), Color(0xFF2A3554)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              driver.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        driver.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (driver.verified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.okSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Tr(
                          '✓ Verified',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ok,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                const Tr(
                  'Substitute driver · driving your car',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                Text(
                  '${driver.trips} ${context.tr('bookings')}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActivityChatScreen(
                      bookingId: booking.id,
                      title: booking.routeLabel,
                      driverName: driver.name,
                    ),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.blue600),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: UnreadDot(bookingId: booking.id, mySenderType: 'user'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareTripRow extends StatefulWidget {
  const _ShareTripRow();

  @override
  State<_ShareTripRow> createState() => _ShareTripRowState();
}

class _ShareTripRowState extends State<_ShareTripRow> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: AppStyles.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tr(
                  'Share booking status',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Tr(
                  _on
                      ? 'Live link active · updates every 30s'
                      : 'Live link off',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: _on,
            activeTrackColor: AppColors.ok,
            onChanged: (v) => setState(() => _on = v),
          ),
        ],
      ),
    );
  }
}
