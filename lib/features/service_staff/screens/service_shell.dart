import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../account/screens/profile_screen.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../providers/service_staff_provider.dart';
import 'service_requests_screen.dart';

class ServiceShell extends StatefulWidget {
  const ServiceShell({super.key});

  @override
  State<ServiceShell> createState() => _ServiceShellState();
}

class _ServiceShellState extends State<ServiceShell> {
  int _index = 0;

  static const _tabs = [
    AppTab(label: 'Home', icon: Icons.home_outlined),
    AppTab(label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final staff = context.read<ServiceStaffProvider>();
      staff.loadServiceCentres();
      staff.loadRequests();
      staff.watchRequests();
      context.read<WeatherProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ServiceRequestsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        tabs: _tabs,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
