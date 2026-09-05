import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';
import '../../models/place.dart';
import 'screen_header.dart';
import 'tr.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({
    super.key,
    this.title = 'Search address',
    this.eyebrow = 'LOCATION',
    this.allowCurrentLocation = false,
  });

  final String title;
  final String eyebrow;
  final bool allowCurrentLocation;

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _controller = TextEditingController();
  final _geocoding = GeocodingService();
  Timer? _debounce;
  List<Place> _results = [];
  bool _searching = false;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Location services are off';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }

      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final point = LatLng(pos.latitude, pos.longitude);
      final address = await _geocoding.reverse(point);
      if (!mounted) return;
      Navigator.of(context)
          .pop(Place(displayName: address, position: point));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get your location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _run(value));
  }

  Future<void> _run(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final places = await _geocoding.search(query);
    if (!mounted) return;
    setState(() {
      _results = places;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(eyebrow: widget.eyebrow, title: widget.title),
          if (widget.allowCurrentLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: InkWell(
                onTap: _locating ? null : _useCurrentLocation,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location,
                              color: AppColors.blue600, size: 18),
                      const SizedBox(width: 10),
                      const Tr(
                        'Use current location',
                        style: TextStyle(
                          color: AppColors.blue700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: context.tr('e.g. Gurney Plaza, Georgetown'),
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Tr(
                      _controller.text.trim().length < 3
                          ? 'Type at least 3 characters to search'
                          : 'No matches found',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, i) {
                      final place = _results[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.blue600,
                        ),
                        title: Text(
                          place.shortName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          place.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.of(context).pop(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
