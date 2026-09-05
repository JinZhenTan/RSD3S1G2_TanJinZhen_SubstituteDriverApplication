import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/account/providers/account_provider.dart';
import 'features/account/providers/preferences_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/booking/providers/booking_provider.dart';
import 'features/driver/providers/driver_provider.dart';
import 'features/driver/screens/driver_shell.dart';
import 'features/service_staff/providers/service_staff_provider.dart';
import 'features/service_staff/screens/service_shell.dart';
import 'features/vehicle_services/providers/car_service_provider.dart';
import 'features/weather_safety/providers/weather_provider.dart';
import 'models/user_role.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );
  final preferences = PreferencesProvider();
  await preferences.load();
  runApp(GantiApp(preferences: preferences));
}

class GantiApp extends StatelessWidget {
  const GantiApp({super.key, required this.preferences});

  final PreferencesProvider preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider<PreferencesProvider>.value(value: preferences),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => CarServiceProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => ServiceStaffProvider()),
      ],
      child: MaterialApp(
        title: 'Ganti',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _profileRequested = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final account = context.watch<AccountProvider>();

    if (!auth.isSignedIn) {
      _profileRequested = false;
      return const LoginScreen();
    }

    if (!_profileRequested) {
      _profileRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AccountProvider>().load();
      });
    }

    if (account.profile == null && account.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = account.profile?.role ?? UserRole.user;
    switch (role) {
      case UserRole.driver:
        return const DriverShell();
      case UserRole.serviceStaff:
        return const ServiceShell();
      case UserRole.user:
        return const AppShell();
    }
  }
}
