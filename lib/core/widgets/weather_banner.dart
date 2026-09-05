import 'package:flutter/material.dart';

import '../../models/weather_alert.dart';
import '../theme/app_theme.dart';
import 'tr.dart';

// Shared Module 2 widget. the brief calls this cross-module reuse out
// explicitly: the same banner appears on Home (inside the navy hero) and on
// the Trip Tracking map. Built once here.
//
// Designed to sit on a dark/navy background (translucent white surface).
class WeatherBanner extends StatelessWidget {
  const WeatherBanner({super.key, required this.alert, this.onTap});

  final WeatherAlert? alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    if (a == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(a.type), size: 18, color: AppColors.heroAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
                    _tagFor(a.severity),
                    style: AppStyles.eyebrow.copyWith(fontSize: 9.5),
                  ),
                  const SizedBox(height: 3),
                  Tr(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${a.area} · ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.heroSubtext,
                          ),
                        ),
                      ),
                      const Tr(
                        'view notifications →',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.heroSubtext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AlertType type) {
    switch (type) {
      case AlertType.flood:
        return Icons.water_drop_outlined;
      case AlertType.roadClosure:
        return Icons.block_outlined;
      case AlertType.rain:
        return Icons.cloud_outlined;
      case AlertType.tripUpdate:
        return Icons.local_taxi_outlined;
    }
  }

  String _tagFor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.severe:
        return 'Severe weather warning';
      case AlertSeverity.moderate:
        return 'Weather advisory';
      case AlertSeverity.info:
        return 'Weather update';
    }
  }
}
