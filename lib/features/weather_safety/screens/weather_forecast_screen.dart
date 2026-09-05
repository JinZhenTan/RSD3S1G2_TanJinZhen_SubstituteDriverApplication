import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../providers/weather_provider.dart';
import '../widgets/forecast_list.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().ensureForecastLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            eyebrow: 'WEATHER & SAFETY',
            title: 'Weather forecast',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  weather.loadForecast(weather.selectedStateId),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: AppStyles.card,
                      child: DropdownButton<String>(
                        value: weather.selectedStateId,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: weather.states.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) weather.loadForecast(value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (weather.isForecastLoading && weather.forecast.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (weather.forecastError != null &&
                      weather.forecast.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          weather.forecastError!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else if (weather.forecast.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Tr(
                          'No forecast available for this state.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    ForecastList(forecastData: weather.forecast),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Tr(
                      'Data source: Malaysian Meteorological Department',
                      style: TextStyle(fontSize: 9, color: Color(0xFF9AA6BC)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
