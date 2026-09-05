import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/place.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  static const String baseUrl = 'https://nominatim.openstreetmap.org';
  static const String userAgent =
      'GantiSubstituteDriverApp/1.0 (student assignment)';

  final Map<String, List<Place>> _cache = {};

  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    if (_cache.containsKey(q)) return _cache[q]!;

    final url = Uri.parse(
      '$baseUrl/search?q=${Uri.encodeQueryComponent(q)}'
      '&format=json&addressdetails=0&limit=6&countrycodes=my',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = (jsonDecode(response.body) as List)
            .cast<Map<String, dynamic>>();
        final places = jsonData.map((json) => Place.fromJson(json)).toList();
        _cache[q] = places;
        return places;
      } else {
        return [];
      }
    } catch (e) {
      print('GeocodingService.search error: $e');
      return [];
    }
  }

  Future<String> reverse(LatLng point) async {
    final url = Uri.parse(
      '$baseUrl/reverse?lat=${point.latitude}&lon=${point.longitude}'
      '&format=json&zoom=17',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final name = data['display_name'] as String?;
        if (name != null && name.isNotEmpty) {
          return name.split(',').take(3).join(',').trim();
        }
      }
    } catch (e) {
      print('GeocodingService.reverse error: $e');
    }
    return '${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)}';
  }
}
