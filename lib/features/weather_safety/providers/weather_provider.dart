import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/weather_service.dart';
import '../../../models/forecast.dart';
import '../../../models/weather_alert.dart';

// Module 2 state. Fetches the data.gov.my weather forecast (Practical 10 way),
// exposes the 7-day forecast list for the Notification screen, and derives the
// safety alerts / banner alert reused on Home and Trip Tracking.
class WeatherProvider extends ChangeNotifier {
  final _service = WeatherService();

  // ---- Safety alerts (banner + feed) ----
  List<WeatherAlert> alerts = [];
  WeatherAlert? bannerAlert;
  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdated;

  // ---- 7-day forecast (Practical 10) ----
  static const String _prefKey = 'weather_state_id';
  final Map<String, String> states = WeatherService.states;
  String selectedStateId = WeatherService.defaultLocationId;
  List<Forecast> forecast = [];
  bool isForecastLoading = false;
  String? forecastError;
  bool _forecastInitStarted = false;

  List<WeatherAlert> get safetyAlerts {
    return alerts.where((a) => a.isSafetyAlert).toList();
  }

  List<WeatherAlert> get updates {
    return alerts.where((a) => !a.isSafetyAlert).toList();
  }

  String get selectedStateName =>
      states[selectedStateId] ?? WeatherService.states[selectedStateId] ?? '';

  Future<void> refresh({bool force = false}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      alerts = await _service.fetchAlerts(force: force);
      bannerAlert = await _service.currentBannerAlert();
      lastUpdated = DateTime.now();
    } catch (e) {
      errorMessage = 'Weather data unavailable right now.';
      print('WeatherProvider.refresh error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }

    await ensureForecastLoaded();
  }

  // Restore the last state the user picked (SharedPreferences) and load its
  // 7-day forecast. Runs once - safe to call from several screens.
  Future<void> ensureForecastLoaded() async {
    if (_forecastInitStarted) return;
    _forecastInitStarted = true;
    await _restoreSelectedState();
    await loadForecast(selectedStateId);
  }

  // Practical 10: fetch the 7-day forecast for one state and remember the
  // choice with SharedPreferences (the practical's TODO).
  Future<void> loadForecast(String locationId) async {
    selectedStateId = locationId;
    isForecastLoading = true;
    forecastError = null;
    notifyListeners();

    try {
      forecast = await _service.fetchForecast(locationId);
      await _saveSelectedState(locationId);
    } catch (e) {
      forecastError = 'Could not load the forecast. Pull to retry.';
      forecast = [];
      print('WeatherProvider.loadForecast error: $e');
    } finally {
      isForecastLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreSelectedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && states.containsKey(saved)) {
        selectedStateId = saved;
      }
    } catch (e) {
      print('WeatherProvider._restoreSelectedState error: $e');
    }
  }

  Future<void> _saveSelectedState(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locationId);
    } catch (e) {
      print('WeatherProvider._saveSelectedState error: $e');
    }
  }

  // Trip updates raised by the booking flow show up in the same feed.
  void addLocalUpdate(WeatherAlert update) {
    alerts = [update, ...alerts];
    notifyListeners();
  }
}
