import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import 'tr.dart';

// A thin wrapper around flutter_map that renders OpenStreetMap raster tiles
//(OSM via flutter_map, not Google Maps) with optional route
// polylines and markers. Used by Find a Driver, Trip Tracking and the
// car-service "drop a pin" screen.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.centre,
    this.zoom = 13,
    this.routePoints = const [],
    this.driverRoutePoints = const [],
    this.markers = const [],
    this.height = 220,
    this.onTap,
    this.controller,
    this.interactive = true,
  });

  final LatLng centre;
  final double zoom;
  final List<LatLng> routePoints; // pickup -> destination (blue)
  final List<LatLng> driverRoutePoints; // driver -> pickup (dashed grey)
  final List<Marker> markers;
  final double height;
  final void Function(LatLng)? onTap;
  final MapController? controller;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: centre,
            initialZoom: zoom,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
            onTap: onTap == null ? null : (_, point) => onTap!(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ganti.app',
              maxZoom: 19,
            ),
            if (driverRoutePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: driverRoutePoints,
                    color: const Color(0xFF5C6C8C),
                    strokeWidth: 3.5,
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),
            if (routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Colors.white,
                    strokeWidth: 7.5,
                  ),
                  Polyline(
                    points: routePoints,
                    color: AppColors.blue600,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Convenience builders for the coloured pin markers used across the app.
  static Marker pin(LatLng point, Color color, {IconData icon = Icons.place}) {
    return Marker(
      point: point,
      width: 34,
      height: 34,
      alignment: Alignment.topCenter,
      child: Icon(icon, color: color, size: 30),
    );
  }

  static Marker dot(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 18,
      height: 18,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}

// A small "what does each colour mean" strip for a MapView above/below it -
// e.g. green = your car, red = destination, blue = driver. Both the
// passenger's and the driver's map screens use this so either side can read
// the other's position at a glance instead of guessing from an unlabelled pin.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.items});

  final List<MapLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Tr(
                item.label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
      ],
    );
  }
}

class MapLegendItem {
  const MapLegendItem(this.color, this.label);
  final Color color;
  final String label;
}
