import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/translation_overrides.dart';
import '../../../core/services/translation_service.dart';

class PreferencesProvider extends ChangeNotifier {
  static const String _languageKey = 'language';
  static const String _safetyPrefix = 'safety_';
  static const String _translationPrefix = 'tr_';
  static const String _seenKey = 'tr_seen';

  static const List<String> languages = [
    'English',
    'Bahasa Malaysia',
    '中文',
    'தமிழ்',
  ];

  static const Map<String, bool> safetyDefaults = {
    'flood_alerts': true,
    'storm_warnings': true,
    'road_closures': true,
    'accident_hotspots': true,
    'auto_safe_reroute': false,
  };

  String language = 'English';
  String? switchingTo;

  Map<String, bool> safety = Map.of(safetyDefaults);
  bool loaded = false;

  final TranslationService _translator = TranslationService();

  final Map<String, Map<String, String>> _cache = {};
  final Set<String> _seen = {};
  final Set<String> _pending = {};
  Timer? _flushTimer;
  Timer? _warmTimer;
  bool _warming = false;
  bool _warmAgain = false;
  bool _seenDirty = false;

  String get _code => TranslationService.languageCodes[language] ?? 'en';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      language = prefs.getString(_languageKey) ?? 'English';
      safety = {
        for (final key in safetyDefaults.keys)
          key: prefs.getBool('$_safetyPrefix$key') ?? safetyDefaults[key]!,
      };

      final seenRaw = prefs.getString(_seenKey);
      if (seenRaw != null) {
        _seen.addAll((jsonDecode(seenRaw) as List).cast<String>());
      }

      for (final code in TranslationService.languageCodes.values) {
        if (code == 'en') continue;
        final raw = prefs.getString('$_translationPrefix$code');
        if (raw != null) {
          final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
          _cache[code] = map.map((k, v) => MapEntry(k, v as String));
        }
      }
    } catch (e) {
      print('PreferencesProvider.load error: $e');
    }
    loaded = true;
    notifyListeners();

    _warmTimer?.cancel();
    _warmTimer = Timer(const Duration(seconds: 3), warmUpAllLanguages);
  }

  Future<void> warmUpAllLanguages() async {
    if (_warming) {
      _warmAgain = true;
      return;
    }
    _warming = true;
    try {
      do {
        _warmAgain = false;
        final snapshot = _seen.toList();
        for (final code in TranslationService.languageCodes.values) {
          if (code == 'en') continue;
          await _ensureCached(code, snapshot);
          if (code == _code) notifyListeners();
        }
      } while (_warmAgain);
    } finally {
      _warming = false;
    }
  }

  Future<void> setLanguage(String value) async {
    if (value == language || value == switchingTo) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, value);
    } catch (e) {
      print('PreferencesProvider.setLanguage error: $e');
    }

    final code = TranslationService.languageCodes[value] ?? 'en';
    if (code == 'en') {
      switchingTo = null;
      language = value;
      notifyListeners();
      return;
    }

    switchingTo = value;
    notifyListeners();
    try {
      await _ensureCached(code, _seen.toList())
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      print('PreferencesProvider.setLanguage timed out: $e');
    }
    language = value;
    switchingTo = null;
    notifyListeners();
  }

  String t(String english) {
    if (_seen.add(english)) _markSeenDirty();

    final code = _code;
    if (code == 'en') return english;

    final override = translationOverrides[code]?[english];
    if (override != null) return override;

    final hit = _cache[code]?[english];
    if (hit != null) return hit;

    _pending.add(english);
    _scheduleFlush();
    return english;
  }

  void _markSeenDirty() {
    _seenDirty = true;
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 250), _flush);
  }

  Future<void> _flush() async {
    final code = _code;
    if (code == 'en' || _pending.isEmpty) return;

    final todo = _pending.toList();
    _pending.clear();
    await _ensureCached(code, todo);
    notifyListeners();
  }

  Future<void> _ensureCached(String code, List<String> englishStrings) async {
    final map = _cache.putIfAbsent(code, () => {});
    final overrides = translationOverrides[code] ?? const {};
    final missing = englishStrings
        .where((s) => !map.containsKey(s) && !overrides.containsKey(s))
        .toList();
    if (missing.isEmpty && !_seenDirty) return;

    if (missing.isNotEmpty) {
      final results = await _translator.translateAll(missing, code);
      map.addAll(results);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (missing.isNotEmpty) {
        await prefs.setString('$_translationPrefix$code', jsonEncode(map));
      }
      if (_seenDirty) {
        await prefs.setString(_seenKey, jsonEncode(_seen.toList()));
        _seenDirty = false;
      }
    } catch (e) {
      print('PreferencesProvider cache save error: $e');
    }
  }

  Future<void> setSafety(String key, bool value) async {
    safety = {...safety, key: value};
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_safetyPrefix$key', value);
    } catch (e) {
      print('PreferencesProvider.setSafety error: $e');
    }
  }

  bool isSafetyTypeEnabled(String key) => safety[key] ?? true;
  bool get autoSafeReroute => safety['auto_safe_reroute'] ?? false;

  @override
  void dispose() {
    _flushTimer?.cancel();
    _warmTimer?.cancel();
    super.dispose();
  }
}
