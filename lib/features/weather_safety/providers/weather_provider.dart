import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/weather_service.dart';
import '../../../models/forecast.dart';
import '../../../models/weather_alert.dart';

class WeatherProvider extends ChangeNotifier {
  final _service = WeatherService();

  List<WeatherAlert> alerts = [];
  WeatherAlert? bannerAlert;
  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdated;

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

  Future<void> ensureForecastLoaded() async {
    if (_forecastInitStarted) return;
    _forecastInitStarted = true;
    await _restoreSelectedState();
    await loadForecast(selectedStateId);
  }

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

  void addLocalUpdate(WeatherAlert update) {
    alerts = [update, ...alerts];
    notifyListeners();
  }
}
