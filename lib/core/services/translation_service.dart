import 'dart:convert';

import 'package:http/http.dart' as http;

// Machine-translation service. English is the source language of every string
// written in the app; this turns an English string into Bahasa Malaysia,
// Mandarin or Tamil on demand using Google's free (unofficial, key-less)
// translate endpoint - the same http.get / jsonDecode pattern as
// weather_service.dart. Anything that fails just falls back to English, so the
// app never breaks when offline.
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  static const String _endpoint =
      'https://translate.googleapis.com/translate_a/single';

  // Our four Language menu names -> the endpoint's language codes.
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Bahasa Malaysia': 'ms',
    '中文': 'zh-CN',
    'தமிழ்': 'ta',
  };

  // Translate one English string. Returns the English text unchanged on any
  // error or if the target is English.
  Future<String> translate(String text, String targetCode) async {
    if (targetCode == 'en' || text.trim().isEmpty) return text;
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'client': 'gtx',
        'sl': 'en',
        'tl': targetCode,
        'dt': 't',
        'q': text,
      });
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return text;

      // Response shape: [[["<translated>","<original>",...], ...], ...]
      final decoded = jsonDecode(response.body) as List;
      final segments = decoded.first as List;
      final buffer = StringBuffer();
      for (final segment in segments) {
        buffer.write((segment as List).first as String);
      }
      final result = buffer.toString();
      return result.isEmpty ? text : result;
    } catch (e) {
      print('TranslationService.translate error: $e');
      return text;
    }
  }

  // Translate a batch of English strings, a few at a time so we do not fire
  // hundreds of requests at once. Returns an english -> translated map. If a
  // whole chunk comes back unchanged (endpoint unreachable / offline) we stop
  // early rather than grind through every remaining chunk.
  Future<Map<String, String>> translateAll(
    List<String> texts,
    String targetCode,
  ) async {
    final out = <String, String>{};
    const chunkSize = 8;
    for (var i = 0; i < texts.length; i += chunkSize) {
      final chunk = texts.skip(i).take(chunkSize).toList();
      final results = await Future.wait(
        chunk.map((t) => translate(t, targetCode)),
      );
      var anyTranslated = false;
      for (var j = 0; j < chunk.length; j++) {
        out[chunk[j]] = results[j];
        if (results[j] != chunk[j]) anyTranslated = true;
      }
      if (!anyTranslated && chunk.length > 1) {
        print('TranslationService: chunk failed, stopping early (offline?)');
        break;
      }
    }
    return out;
  }
}
