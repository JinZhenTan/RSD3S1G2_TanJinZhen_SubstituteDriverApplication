import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/weather_alert.dart';

// One alert card in the Notification feed. The colour and icon come from the
// alert's type / severity.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColour(alert);
    final fg = _foregroundColour(alert);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon(alert.type), size: 17, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Tr(
                  alert.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${alert.isSafetyAlert ? 'SAFETY ALERT' : 'UPDATE'} · '
                  '${alert.source.toUpperCase()} · ${_ago(alert.createdAt)}',
                  style: AppStyles.mono.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _backgroundColour(WeatherAlert a) {
    if (!a.isSafetyAlert) return AppColors.blue50;
    switch (a.severity) {
      case AlertSeverity.severe:
        return AppColors.dangerSoft;
      case AlertSeverity.moderate:
        return AppColors.warnSoft;
      case AlertSeverity.info:
        return AppColors.okSoft;
    }
  }

  Color _foregroundColour(WeatherAlert a) {
    if (!a.isSafetyAlert) return AppColors.blue600;
    switch (a.severity) {
      case AlertSeverity.severe:
        return AppColors.danger;
      case AlertSeverity.moderate:
        return AppColors.warn;
      case AlertSeverity.info:
        return AppColors.ok;
    }
  }

  IconData _icon(AlertType type) {
    switch (type) {
      case AlertType.flood:
        return Icons.water_drop;
      case AlertType.rain:
        return Icons.thunderstorm_outlined;
      case AlertType.roadClosure:
        return Icons.block;
      case AlertType.tripUpdate:
        return Icons.directions_car;
    }
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes} MIN AGO';
    if (diff.inHours < 24) return '${diff.inHours} HR AGO';
    return DateFormat('d MMM').format(t).toUpperCase();
  }
}
