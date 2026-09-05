import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../../models/home_action.dart';
import '../../account/providers/account_provider.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../../../core/widgets/weather_banner.dart';
import '../providers/booking_provider.dart';
import 'find_driver_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_tracking_screen.dart';
import '../../vehicle_services/screens/car_service_form_screen.dart';
import '../../weather_safety/screens/weather_forecast_screen.dart';

// Module 1 - Home tab. Navy hero with greeting + the shared weather banner,
// a 2x2 grid of quick actions, and a "last booking" card.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTab,
    this.primaryAction,
    this.showCarService = true,
    this.secondaryAction,
  });

  // Lets the quick-action tiles jump to the Notification / Profile tabs that
  // live in the shell's bottom nav (index 2 and 3).
  final void Function(int) onOpenTab;

  // The first quick-action tile. Null in the passenger app (defaults to
  // "Find a Driver"); the driver app passes an "Available bookings" action.
  final HomeAction? primaryAction;

  // Car Service is a passenger-only feature - a substitute driver drives the
  // passenger's car and has no vehicle to service. The driver app hides it.
  final bool showCarService;

  // A second quick-action tile shown right after the primary one. Unused in
  // the passenger app; the driver app passes an "Earnings" action so it does
  // not have to dig into Profile to see how much they've made.
  final HomeAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final weather = context.watch<WeatherProvider>();
    final booking = context.watch<BookingProvider>();
    final name = account.profile?.name ?? 'there';

    final primary = primaryAction ??
        HomeAction(
          icon: Icons.person_pin_circle_outlined,
          title: 'Find a Driver',
          subtitle: 'We drive your own car home',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => const FindDriverScreen()),
          ),
        );

    return Container(
      color: AppColors.page,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            name: name,
            initial: account.profile?.initial ?? 'G',
            weather: weather,
            onBannerTap: () => onOpenTab(2),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Tr('Quick actions', style: AppStyles.sectionTitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 126,
              ),
              children: [
                _Tile(
                  icon: primary.icon,
                  title: primary.title,
                  subtitle: primary.subtitle,
                  onTap: () => primary.onTap(context),
                ),
                if (secondaryAction != null)
                  _Tile(
                    icon: secondaryAction!.icon,
                    title: secondaryAction!.title,
                    subtitle: secondaryAction!.subtitle,
                    onTap: () => secondaryAction!.onTap(context),
                  ),
                if (showCarService)
                  _Tile(
                    icon: Icons.build_outlined,
                    title: 'Car Service',
                    subtitle: 'Schedule maintenance drop-off',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CarServiceFormScreen(),
                      ),
                    ),
                  ),
                _Tile(
                  icon: Icons.wb_cloudy_outlined,
                  title: 'Weather Forecast',
                  subtitle: '7-day outlook by state',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WeatherForecastScreen(),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: showCarService
                      ? 'Account & vehicle'
                      : 'Account & preferences',
                  onTap: () => onOpenTab(3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Tr('Last booking', style: AppStyles.sectionTitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LastTripCard(booking: booking),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.initial,
    required this.weather,
    required this.onBannerTap,
  });

  final String name;
  final String initial;
  final WeatherProvider weather;
  final VoidCallback onBannerTap;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppStyles.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr(
                      _greeting,
                      style: const TextStyle(
                        color: AppColors.heroSubtext,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.blue500, AppColors.blue700],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (weather.isLoading && weather.bannerAlert == null)
              const _BannerSkeleton()
            else
              WeatherBanner(alert: weather.bannerAlert, onTap: onBannerTap),
          ],
        ),
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Tr(
        'Checking weather…',
        style: TextStyle(color: AppColors.heroSubtext, fontSize: 12),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppStyles.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.blue600, size: 19),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Tr(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastTripCard extends StatelessWidget {
  const _LastTripCard({required this.booking});

  final BookingProvider booking;

  @override
  Widget build(BuildContext context) {
    final trips = booking.pastBookings;
    if (trips.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.card,
        child: const Tr(
          'No bookings yet — book a substitute driver from Quick actions above.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
      );
    }

    final last = trips.first;
    return InkWell(
      onTap: () => _open(context, last),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    last.routeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                _StatusPill(status: last.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('d MMM, h:mm a').format(last.createdAt),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                Text(
                  'RM ${(last.fareFinal ?? last.fareEstimate).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Same rule as the Activity tab's rows: a finished trip opens the static
  // detail screen, one still in progress opens the live Trip Tracking screen
  // so the map/ETA/confirm-completion button keep updating.
  Future<void> _open(BuildContext context, Booking last) async {
    if (bookingIsHistory(last.status)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(booking: last)),
      );
      return;
    }
    await context.read<BookingProvider>().resumeTrip(last);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TripTrackingScreen()),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == BookingStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: done ? AppColors.okSoft : AppColors.blue50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Tr(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: done ? AppColors.ok : AppColors.blue700,
        ),
      ),
    );
  }
}
