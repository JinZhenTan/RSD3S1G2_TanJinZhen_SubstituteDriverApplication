import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../providers/preferences_provider.dart';

// Module 4 - Safety alert preferences. DEVICE-level toggles held in
// PreferencesProvider (shared_preferences). They tune what the Notification
// feed shows on this phone and whether the safe-route card auto-applies -
// unlike account-level notification_settings in Supabase.
class SafetyPreferencesScreen extends StatelessWidget {
  const SafetyPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesProvider>();

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            eyebrow: 'PREFERENCES',
            title: 'Safety alert preferences',
          ),
          Expanded(
            child: !prefs.loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          border: Border.all(color: AppColors.blue100),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Tr(
                          'Alerts are powered by data.gov.my, MetMalaysia and '
                          'PDRM open data feeds. These toggles filter the '
                          'Notification feed on this device.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.blue700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: AppStyles.card,
                        child: Column(
                          children: [
                            _row(context, prefs, 'flood_alerts',
                                'Flood alerts',
                                'Notify when a route ahead is flooded'),
                            _row(context, prefs, 'storm_warnings',
                                'Heavy rain / storm warnings',
                                'MetMalaysia severe weather bulletins'),
                            _row(context, prefs, 'road_closures',
                                'Road closures',
                                'Planned works & incident closures'),
                            _row(context, prefs, 'accident_hotspots',
                                'Accident hotspots',
                                'Warn near known high-risk stretches'),
                            _row(context, prefs, 'auto_safe_reroute',
                                'Automatic safe rerouting',
                                'Apply a safer detour without asking',
                                last: true),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    PreferencesProvider prefs,
    String key,
    String title,
    String subtitle, {
    bool last = false,
  }) {
    return Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Tr(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: prefs.safety[key] ?? false,
            activeTrackColor: AppColors.ok,
            onChanged: (v) =>
                context.read<PreferencesProvider>().setSafety(key, v),
          ),
        ],
      ),
    );
  }
}
