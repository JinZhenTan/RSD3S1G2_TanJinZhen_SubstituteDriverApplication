import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/location_search_screen.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/place.dart';
import '../providers/car_service_provider.dart';
import 'pick_map_screen.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  bool _locating = false;

  Future<void> _useGps() async {
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

      final pos = await Geolocator.getCurrentPosition();
      final point = LatLng(pos.latitude, pos.longitude);
      final address = await GeocodingService().reverse(point);
      if (!mounted) return;
      context.read<CarServiceProvider>().setPickup(address, point);
      _pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const PickMapScreen()),
    );
    if (result == null || !mounted) return;
    context.read<CarServiceProvider>().setPickup(result.address, result.point);
    _pop();
  }

  Future<void> _enterManually() async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => const LocationSearchScreen(
          eyebrow: 'VEHICLE CARE',
          title: 'Enter pick-up address',
        ),
      ),
    );
    if (place == null || !mounted) return;
    context.read<CarServiceProvider>().setPickup(place.shortName, place.position);
    _pop();
  }

  void _pop() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            eyebrow: 'VEHICLE CARE',
            title: 'Pick-up location',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _MethodTile(
                  icon: Icons.my_location,
                  title: 'Use current GPS location',
                  subtitle: 'Auto-detect where you are now',
                  loading: _locating,
                  onTap: _useGps,
                ),
                const SizedBox(height: 12),
                _MethodTile(
                  icon: Icons.location_on_outlined,
                  title: 'Choose on map',
                  subtitle: 'Drop a pin at the exact spot',
                  onTap: _pickOnMap,
                ),
                const SizedBox(height: 12),
                _MethodTile(
                  icon: Icons.keyboard_outlined,
                  title: 'Enter address manually',
                  subtitle: 'Type in the pick-up address',
                  onTap: _enterManually,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.card,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: AppColors.blue600, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Tr(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
