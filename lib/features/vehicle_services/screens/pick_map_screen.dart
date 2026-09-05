import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';

// The value popped back from the "drop a pin" screen.
class PickedLocation {
  final LatLng point;
  final String address;
  PickedLocation(this.point, this.address);
}

// Module 3 - Drop a pin. The centre of the map is the chosen point (a fixed
// centre crosshair over a movable map, like the prototype). On confirm we
// reverse-geocode the centre to a readable address.
class PickMapScreen extends StatefulWidget {
  const PickMapScreen({super.key});

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  final _controller = MapController();
  LatLng _centre = const LatLng(5.4141, 100.3288);
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'VEHICLE CARE', title: 'Drop a pin'),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _centre,
                    initialZoom: 14,
                    onPositionChanged: (camera, _) =>
                        _centre = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ganti.app',
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 30),
                  child: Icon(
                    Icons.place,
                    color: AppColors.blue600,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Tr(
                  'Move the map so the pin sits at your exact pick-up spot',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Confirm this location',
                  icon: Icons.arrow_forward,
                  loading: _resolving,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    setState(() => _resolving = true);
                    final address =
                        await GeocodingService().reverse(_centre);
                    if (!mounted) return;
                    navigator.pop(PickedLocation(_centre, address));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
