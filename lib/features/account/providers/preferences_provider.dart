import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/translation_overrides.dart';
import '../../../core/services/translation_service.dart';

// Device-level preferences (Module 4) kept with SharedPreferences, like the
// user_profile practical. These tune what THIS phone shows and do not need to
// sync across devices - unlike notification_settings, which are account-level
// in Supabase. Kept in a provider so the Profile menu label, the Notification
// feed and the safe-route card all react to a change immediately.
//
// This provider also drives the app's UI language. Every visible string is
// written in English; t('English text') returns the machine translation for
// the chosen language. Translations are cached in SharedPreferences so a
// language is only downloaded once, and the app pre-warms every language in
// the background so that picking one on the Language screen switches instantly
// with no English flash.
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

  // key -> default value
  static const Map<String, bool> safetyDefaults = {
    'flood_alerts': true,
    'storm_warnings': true,
    'road_closures': true,
    'accident_hotspots': true,
    'auto_safe_reroute': false,
  };

  String language = 'English';
  // While a non-English language is being fetched, this holds the target so the
  // Language screen can show a spinner on that row. The committed `language`
  // only flips once every string is ready, so there is never a half-translated
  // frame.
  String? switchingTo;

  Map<String, bool> safety = Map.of(safetyDefaults);
  bool loaded = false;

  final TranslationService _translator = TranslationService();

  // languageCode -> (english -> translated). Loaded from SharedPreferences and
  // topped up by the translation API.
  final Map<String, Map<String, String>> _cache = {};
  // Every English string the app has ever rendered (persisted). The background
  // warm-up translates this whole set into every language.
  final Set<String> _seen = {};
  // Strings still waiting for the lazy per-string fallback fetch.
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

      // Restore cached translations for the non-English languages.
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

    // A little after the first screens have rendered (and filled _seen),
    // translate everything into every language in the background so a later
    // switch is instant.
    _warmTimer?.cancel();
    _warmTimer = Timer(const Duration(seconds: 3), warmUpAllLanguages);
  }

  // Called from the Language screen so translations are ready before the user
  // taps a row. If called again while already running, it re-runs once more
  // afterwards so any strings seen in between are picked up.
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

    // Persist the choice immediately so it survives even if the fetch below is
    // interrupted or the app is closed mid-switch.
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

    // Fetch anything not already cached, THEN flip - so the switch is clean.
    // Cap the wait: if the network is slow/offline, switch anyway after a few
    // seconds and let the remaining strings fill in lazily (or stay English).
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

  // The translation lookup used by the Tr widget / context.tr(). Returns the
  // English text immediately; if a translation is needed but not cached yet it
  // queues a download and the widget rebuilds once it arrives (the fallback
  // path - normally the warm-up has already cached everything).
  String t(String english) {
    if (_seen.add(english)) _markSeenDirty();

    final code = _code;
    if (code == 'en') return english;

    // Hand-picked correction wins over the machine translation.
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

  // Translate any of `englishStrings` missing from the cache for `code`, then
  // persist the updated map (and the seen-set).
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
