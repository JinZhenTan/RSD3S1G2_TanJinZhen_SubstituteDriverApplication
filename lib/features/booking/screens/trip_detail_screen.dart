import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../supabase_config.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../../models/driver.dart';
import '../../../models/profile.dart';
import '../../../models/route_result.dart';
import 'activity_chat_screen.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Driver? _driver;
  bool _loadingDriver = false;
  RouteResult? _route;
  bool _loadingRoute = true;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final driverId = widget.booking.driverId;
    if (driverId != null) {
      _loadingDriver = true;
      supabase
          .from('profiles')
          .select()
          .eq('id', driverId)
          .maybeSingle()
          .then((row) {
        if (!mounted) return;
        setState(() {
          _loadingDriver = false;
          if (row != null) {
            _driver = Driver.fromProfile(Profile.fromJson(row));
          }
        });
      }).catchError((e) {
        print('TripDetailScreen driver load error: $e');
        if (mounted) setState(() => _loadingDriver = false);
      });
    }

    final booking = widget.booking;
    RoutingService()
        .route(
          LatLng(booking.pickupLat, booking.pickupLng),
          LatLng(booking.destLat, booking.destLng),
        )
        .then((route) {
      if (!mounted) return;
      setState(() {
        _route = route;
        _loadingRoute = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(route.points),
            padding: const EdgeInsets.all(36),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final fare = booking.fareFinal ?? booking.fareEstimate;
    final pickup = LatLng(booking.pickupLat, booking.pickupLng);
    final dest = LatLng(booking.destLat, booking.destLng);
    final centre = LatLng(
      (booking.pickupLat + booking.destLat) / 2,
      (booking.pickupLng + booking.destLng) / 2,
    );

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(eyebrow: 'ACTIVITY', title: booking.serviceTier.label),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                if (_loadingRoute)
                  Container(
                    height: 200,
                    decoration: AppStyles.card,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  )
                else
                  MapView(
                    controller: _mapController,
                    centre: centre,
                    zoom: 12,
                    routePoints: _route?.points ?? [pickup, dest],
                    markers: [
                      MapView.dot(pickup, AppColors.ok),
                      MapView.pin(dest, AppColors.danger),
                    ],
                    height: 200,
                    interactive: false,
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppStyles.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoutePoint(color: AppColors.blue600, label: booking.pickupAddress),
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Container(width: 2, height: 18, color: AppColors.line),
                      ),
                      _RoutePoint(color: AppColors.ink, label: booking.destAddress),
                      const Divider(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEE, d MMM · h:mm a').format(booking.createdAt),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                          _StatusPill(status: booking.status),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _NavyRow(label: 'Service tier', value: booking.serviceTier.label),
                      const SizedBox(height: 8),
                      _NavyRow(label: 'Payment method', value: booking.paymentMethod),
                      const SizedBox(height: 8),
                      _NavyRow(
                        label: 'Payment status',
                        value: booking.paymentStatus.toUpperCase(),
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Tr(
                            booking.fareFinal != null ? 'Final fare' : 'Fare estimate',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'RM ${fare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.heroAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (booking.completedBy == 'driver') ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warnSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Tr(
                          'Completed by your driver, not confirmed by you',
                          style: TextStyle(
                            color: AppColors.warn,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (booking.completionNote != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${booking.completionNote}',
                            style: const TextStyle(
                              color: AppColors.warn,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_loadingDriver)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_driver != null)
                  _DriverRow(driver: _driver!),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Chat history',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActivityChatScreen(
                        bookingId: booking.id,
                        title: booking.routeLabel,
                        driverName: _driver?.name ?? 'Driver',
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (status) {
      case BookingStatus.completed:
        fg = AppColors.ok;
        bg = AppColors.okSoft;
        break;
      case BookingStatus.cancelled:
        fg = AppColors.danger;
        bg = AppColors.dangerSoft;
        break;
      case BookingStatus.searching:
        fg = AppColors.warn;
        bg = AppColors.warnSoft;
        break;
      case BookingStatus.enRoute:
      case BookingStatus.onTrip:
        fg = AppColors.blue600;
        bg = AppColors.blue50;
        break;
      case BookingStatus.arrived:
        fg = AppColors.warn;
        bg = AppColors.warnSoft;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Tr(
        bookingStatusLabel(status),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _NavyRow extends StatelessWidget {
  const _NavyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Tr(label, style: const TextStyle(color: Color(0xFF9AACC9), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
                const Tr(
                  'Substitute driver',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
