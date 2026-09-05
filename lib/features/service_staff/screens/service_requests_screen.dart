import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../core/widgets/weather_banner.dart';
import '../../account/providers/account_provider.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../../weather_safety/screens/weather_forecast_screen.dart';
import '../providers/service_staff_provider.dart';
import 'service_stage_list_screen.dart';
import 'staff_earnings_screen.dart';

// Service staff role - Home tab. Same dashboard pattern as the passenger and
// driver Home tabs: a navy hero (greeting + weather banner) and a "Quick
// actions" grid - here, one tile per job stage (Pickup / Service / Return).
// Each tile opens a list scoped to only the jobs at that stage; there is no
// combined job list on this page itself.
class ServiceRequestsScreen extends StatelessWidget {
  const ServiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final weather = context.watch<WeatherProvider>();
    final name = account.profile?.name ?? 'there';

    return Container(
      color: AppColors.page,
      child: RefreshIndicator(
        onRefresh: () => context.read<ServiceStaffProvider>().loadRequests(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(
              name: name,
              initial: account.profile?.initial ?? 'G',
              weather: weather,
              onBannerTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WeatherForecastScreen(),
                ),
              ),
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
                    icon: Icons.directions_car_outlined,
                    title: 'Pickup',
                    subtitle: 'Collect cars from their owners',
                    onTap: () => _openStage(context, StaffStage.pickup),
                  ),
                  _Tile(
                    icon: Icons.build_outlined,
                    title: 'Service',
                    subtitle: 'Cars being worked on at the centre',
                    onTap: () => _openStage(context, StaffStage.service),
                  ),
                  _Tile(
                    icon: Icons.assignment_return_outlined,
                    title: 'Return',
                    subtitle: 'Send finished cars back to owners',
                    onTap: () => _openStage(context, StaffStage.returnTrip),
                  ),
                  _Tile(
                    icon: Icons.payments_outlined,
                    title: 'Earnings',
                    subtitle: 'Salary, job pay & deductions',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StaffEarningsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openStage(BuildContext context, StaffStage stage) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceStageListScreen(stage: stage),
      ),
    );
  }
}

// ---- hero ------------------------------------------------------------
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
            Tr('CAR SERVICE PARTNER', style: AppStyles.eyebrow),
            const SizedBox(height: 8),
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
              Container(
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
              )
            else
              WeatherBanner(alert: weather.bannerAlert, onTap: onBannerTap),
          ],
        ),
      ),
    );
  }
}

// ---- quick-action tile (same look as the passenger/driver Home tiles) --
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

