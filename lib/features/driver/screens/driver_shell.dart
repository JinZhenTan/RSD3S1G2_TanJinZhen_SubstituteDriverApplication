import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../models/home_action.dart';
import '../../account/screens/profile_screen.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/screens/activity_screen.dart';
import '../../booking/screens/home_screen.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../../weather_safety/screens/notification_screen.dart';
import '../providers/driver_provider.dart';
import 'driver_jobs_screen.dart';
import 'earnings_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  static const _tabs = [
    AppTab(label: 'Home', icon: Icons.home_outlined),
    AppTab(label: 'Activity', icon: Icons.history),
    AppTab(label: 'Notification', icon: Icons.notifications_outlined),
    AppTab(label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driver = context.read<DriverProvider>();
      driver.loadJobs();
      driver.watchAvailableJobs();
      context.read<WeatherProvider>().refresh();
      context.read<BookingProvider>().loadActivity();
    });
  }

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenTab: _goToTab,
            showCarService: false,
            primaryAction: HomeAction(
              icon: Icons.assignment_outlined,
              title: 'Available bookings',
              subtitle: 'Review & accept nearby requests',
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const DriverJobsScreen()),
              ),
            ),
            secondaryAction: HomeAction(
              icon: Icons.payments_outlined,
              title: 'Earnings',
              subtitle: 'Salary, booking pay & deductions',
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const EarningsScreen()),
              ),
            ),
          ),
          const ActivityScreen(),
          const NotificationScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        tabs: _tabs,
        currentIndex: _index,
        onTap: _goToTab,
      ),
    );
  }
}
