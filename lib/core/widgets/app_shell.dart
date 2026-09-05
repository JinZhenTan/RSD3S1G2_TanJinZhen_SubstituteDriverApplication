import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/account/screens/profile_screen.dart';
import '../../features/booking/screens/activity_screen.dart';
import '../../features/booking/screens/home_screen.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../features/weather_safety/screens/notification_screen.dart';
import '../../features/weather_safety/providers/weather_provider.dart';
import 'bottom_nav_bar.dart';

const _tabs = [
  AppTab(label: 'Home', icon: Icons.home_outlined),
  AppTab(label: 'Activity', icon: Icons.history),
  AppTab(label: 'Notification', icon: Icons.notifications_outlined),
  AppTab(label: 'Profile', icon: Icons.person_outline),
];

// Signed-in app shell: bottom nav + the 4 top-level tab bodies, matching the
// prototype's tabbar (view-home / view-activity / view-notification /
// view-profile). Each tab keeps its state via IndexedStack.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // The profile is already loaded by AuthGate; pull the rest here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          HomeScreen(onOpenTab: _goToTab),
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
