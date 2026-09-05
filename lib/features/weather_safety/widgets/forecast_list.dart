import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/forecast.dart';

// Practical 10: a Bahasa Malaysia forecast phrase -> a weather condition image
// file bundled in assets/images/. This is the practical's `weather_status` map,
// kept verbatim (same keys, same filenames). Any phrase not in the map falls
// through _imageFor()'s keyword check, then to unknown.png.
const Map<String, String> _weatherStatus = {
  'Berjerebu': 'haze.png',
  'Tiada hujan': 'sunny.png',
  'Hujan': 'rainy.png',
  'Hujan di beberapa tempat': 'rainy.png',
  'Hujan di satu dua tempat': 'rainy.png',
  'Hujan di satu dua tempat di kawasan pantai': 'rainy.png',
  'Hujan di satu dua tempat di kawasan pedalaman': 'rainy.png',
  'Ribut petir': 'thunderstorm.png',
  'Ribut petir di beberapa tempat': 'thunderstorm.png',
  'Ribut petir di beberapa tempat di kawasan pedalaman': 'thunderstorm.png',
  'Ribut petir di satu dua tempat': 'thunderstorm.png',
  'Ribut petir di satu dua tempat di kawasan pantai': 'thunderstorm.png',
  'Ribut petir di satu dua tempat di kawasan pedalaman': 'thunderstorm.png',
};

// Resolve a forecast phrase to an asset filename. Exact map first (Practical
// 10), then a loose keyword match so unseen MET wordings still get an image,
// then unknown.png.
String _imageFor(String forecastText) {
  final exact = _weatherStatus[forecastText];
  if (exact != null) return exact;

  final t = forecastText.toLowerCase();
  // "Tiada hujan" (no rain) contains "hujan", so check it before "hujan".
  if (t.contains('tiada hujan') || t.contains('no rain') || t.contains('cerah')) {
    return 'sunny.png';
  }
  if (t.contains('ribut petir') || t.contains('thunderstorm')) {
    return 'thunderstorm.png';
  }
  if (t.contains('jerebu') || t.contains('haze')) return 'haze.png';
  if (t.contains('hujan') || t.contains('rain') || t.contains('showers')) {
    return 'rainy.png';
  }
  if (t.contains('berawan') || t.contains('cloud') || t.contains('mendung')) {
    return 'cloudy.png';
  }
  return 'unknown.png';
}

// Practical 10: a ListView.builder of Cards, one per forecast day. Each card is
// a ListTile - leading day/month, title min/max temp, subtitle a row of the
// morning / afternoon / night condition images.
class ForecastList extends StatelessWidget {
  const ForecastList({super.key, required this.forecastData});

  final List<Forecast> forecastData;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: forecastData.length,
      itemBuilder: (context, index) {
        final forecast = forecastData[index];
        final date = DateTime.tryParse(forecast.date);
        final dayLabel = date == null
            ? forecast.date
            : '${date.day} / ${date.month}';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Text(
              dayLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            title: Text(
              '${forecast.min_temp}°C  ${forecast.max_temp}°C',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.ink,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Segment(
                    label: 'Morning',
                    forecastText: forecast.morning_forecast,
                  ),
                  const Expanded(child: SizedBox()),
                  _Segment(
                    label: 'Afternoon',
                    forecastText: forecast.afternoon_forecast,
                  ),
                  const Expanded(child: SizedBox()),
                  _Segment(
                    label: 'Night',
                    forecastText: forecast.night_forecast,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// One time-of-day column: label + the condition image (Practical 10 uses
// Image.asset at 48x48, with unknown.png as the missing-asset fallback).
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.forecastText});

  final String label;
  final String forecastText;

  @override
  Widget build(BuildContext context) {
    final file = _imageFor(forecastText);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Tr(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Image.asset(
          'assets/images/$file',
          width: 48,
          height: 48,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/unknown.png',
            width: 48,
            height: 48,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.help_outline, size: 32, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
