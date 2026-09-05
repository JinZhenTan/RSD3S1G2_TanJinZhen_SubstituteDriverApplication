import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../../models/car_service_request.dart';
import '../../../models/notification_settings.dart';
import '../../../models/weather_alert.dart';
import '../../account/providers/account_provider.dart';
import '../../account/providers/preferences_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/alert_card.dart';
import '../widgets/safe_route_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _filter = 0;

  List<WeatherAlert> _safety(
    WeatherProvider weather,
    NotificationSettings ns,
    PreferencesProvider prefs,
  ) {
    if (!ns.safetyAlerts) return const [];
    return weather.safetyAlerts.where((a) {
      switch (a.type) {
        case AlertType.flood:
          return prefs.isSafetyTypeEnabled('flood_alerts');
        case AlertType.rain:
          return prefs.isSafetyTypeEnabled('storm_warnings');
        case AlertType.roadClosure:
          return prefs.isSafetyTypeEnabled('road_closures');
        case AlertType.tripUpdate:
          return true;
      }
    }).toList();
  }

  List<WeatherAlert> _updates(BookingProvider booking, NotificationSettings ns) {
    final items = <WeatherAlert>[];

    if (ns.tripUpdates && booking.pastBookings.isNotEmpty) {
      final b = booking.pastBookings.first;
      items.add(
        WeatherAlert(
          id: 'trip-${b.id}',
          type: AlertType.tripUpdate,
          severity: AlertSeverity.info,
          title: 'Booking ${_tripStatusLabel(b.status)}',
          description: b.routeLabel,
          area: 'Substitute driver',
          source: 'Ganti',
          createdAt: b.createdAt,
        ),
      );
    }

    if (ns.carServiceUpdates && booking.pastServiceRequests.isNotEmpty) {
      final r = booking.pastServiceRequests.first;
      items.add(
        WeatherAlert(
          id: 'svc-${r.id}',
          type: AlertType.tripUpdate,
          severity: AlertSeverity.info,
          title: 'Car service — ${carServiceStatusLabel(r.status)}',
          description: '${r.serviceTypesLabel} · ${r.pickupAddress}',
          area: 'Vehicle care',
          source: 'Ganti',
          createdAt: r.createdAt,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  String _tripStatusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.searching:
        return 'finding a driver';
      case BookingStatus.enRoute:
        return 'driver on the way';
      case BookingStatus.onTrip:
        return 'in progress';
      case BookingStatus.arrived:
        return 'waiting for you to confirm';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final prefs = context.watch<PreferencesProvider>();
    final ns = context.watch<AccountProvider>().notificationSettings;
    final booking = context.watch<BookingProvider>();

    final safety = _safety(weather, ns, prefs);
    final updates = _updates(booking, ns);
    List<WeatherAlert> visible;
    if (_filter == 1) {
      visible = safety;
    } else if (_filter == 2) {
      visible = updates;
    } else {
      visible = [...safety, ...updates];
    }

    return Container(
      color: AppColors.page,
      child: RefreshIndicator(
        onRefresh: () => weather.refresh(force: true),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr('LIVE FEED', style: AppStyles.eyebrow),
                    const SizedBox(height: 6),
                    Tr(
                      'Notification',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: _Segmented(
                labels: [
                  context.tr('All'),
                  context.tr('Safety alerts'),
                  context.tr('Updates'),
                ],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ),
            if (!ns.safetyAlerts && _filter != 2)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _MutedNote(
                  text: 'Safety alerts are muted. Turn them on in '
                      'Profile → Notification settings.',
                ),
              ),
            if (weather.isLoading && visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (weather.errorMessage != null && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    weather.errorMessage!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Tr(
                    'Nothing here right now — roads are clear.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            ...visible.map((a) => AlertCard(alert: a)),
            if (_filter != 2 && safety.isNotEmpty) const SafeRouteCard(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Tr(
                'Powered by data.gov.my · MetMalaysia · PDRM Open Data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9AA6BC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedNote extends StatelessWidget {
  const _MutedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 16, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Tr(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.warn),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: i == index ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
