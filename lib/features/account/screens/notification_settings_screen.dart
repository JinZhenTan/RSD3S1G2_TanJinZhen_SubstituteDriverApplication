import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/notification_settings.dart';
import '../providers/account_provider.dart';

// Module 4 - Notification settings. Account-level toggles persisted to the
// Supabase `notification_settings` table (they follow the user across devices).
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final s = account.notificationSettings;

    void update(NotificationSettings next) =>
        context.read<AccountProvider>().updateNotificationSettings(next);

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            eyebrow: 'PREFERENCES',
            title: 'Notification settings',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Container(
                  decoration: AppStyles.card,
                  child: Column(
                    children: [
                      _ToggleRow(
                        title: 'Booking updates',
                        subtitle: 'Driver assigned, arriving, booking complete',
                        value: s.tripUpdates,
                        onChanged: (v) =>
                            update(s.copyWith(tripUpdates: v)),
                      ),
                      _ToggleRow(
                        title: 'Safety alerts',
                        subtitle: 'Flood, road closure & weather warnings',
                        value: s.safetyAlerts,
                        onChanged: (v) =>
                            update(s.copyWith(safetyAlerts: v)),
                      ),
                      _ToggleRow(
                        title: 'Car service updates',
                        subtitle: 'Pick-up, workshop & return status',
                        value: s.carServiceUpdates,
                        onChanged: (v) =>
                            update(s.copyWith(carServiceUpdates: v)),
                      ),
                      _ToggleRow(
                        title: 'Chat messages',
                        subtitle: 'New messages from your driver',
                        value: s.chatMessages,
                        onChanged: (v) =>
                            update(s.copyWith(chatMessages: v)),
                      ),
                      _ToggleRow(
                        title: 'Promotions',
                        subtitle: 'Discounts and referral rewards',
                        value: s.promotions,
                        onChanged: (v) =>
                            update(s.copyWith(promotions: v)),
                        last: true,
                      ),
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
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.line),
              ),
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
            value: value,
            activeTrackColor: AppColors.ok,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
