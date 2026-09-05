import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/route_result.dart';
import '../../account/providers/preferences_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/weather_provider.dart';

// Module 2 - Safe-route suggestion. Compares OSRM's default route for the
// active booking against an alternative that stays further from the flagged
// hazard coordinates, and offers to apply it.
//
// Simplification documented: a "real" implementation would
// route around a hazard polygon; here we just pick whichever OSRM alternative
// keeps the greatest clearance from the hazard points.
class SafeRouteCard extends StatefulWidget {
  const SafeRouteCard({super.key});

  @override
  State<SafeRouteCard> createState() => _SafeRouteCardState();
}

class _SafeRouteCardState extends State<SafeRouteCard> {
  RouteResult? _safe;
  int _extraMinutes = 0;
  bool _computing = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _compute());
  }

  Future<void> _compute() async {
    final booking = context.read<BookingProvider>();
    final weather = context.read<WeatherProvider>();
    final b = booking.activeBooking;
    final current = booking.tripRoute;
    if (b == null || current == null) return;

    setState(() => _computing = true);
    final safe = await RoutingService().safeRoute(
      LatLng(b.pickupLat, b.pickupLng),
      LatLng(b.destLat, b.destLng),
      weather.safetyAlerts,
    );
    if (!mounted) return;
    setState(() {
      _safe = safe;
      _extraMinutes =
          (safe.durationMinutes - current.durationMinutes).clamp(0, 120);
      _computing = false;
    });

    // Device preference: apply the safer route without asking.
    if (context.read<PreferencesProvider>().autoSafeReroute && !_applied) {
      context.read<BookingProvider>().applySafeRoute(safe);
      setState(() => _applied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertCount = context.watch<WeatherProvider>().safetyAlerts.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.okSoft,
        border: Border.all(color: const Color(0xFFBFE3D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, size: 15, color: AppColors.ok),
              SizedBox(width: 6),
              Tr(
                'Safer route available',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Tr(
            _computing
                ? 'Checking for a safer route around active alerts…'
                : _safe == null
                    ? 'Start a booking to get a safe-route suggestion that '
                        'avoids $alertCount active alert${alertCount == 1 ? '' : 's'}.'
                    : 'Rerouting your active booking adds about $_extraMinutes '
                        'minute${_extraMinutes == 1 ? '' : 's'} but avoids '
                        '$alertCount active alert${alertCount == 1 ? '' : 's'}.',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF1E5C43),
              height: 1.4,
            ),
          ),
          if (_safe != null) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ok,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
              ),
              onPressed: _applied
                  ? null
                  : () {
                      context.read<BookingProvider>().applySafeRoute(_safe!);
                      setState(() => _applied = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Safe route applied to your booking'),
                        ),
                      );
                    },
              child: Tr(_applied ? 'Safe route applied' : 'Apply safe route'),
            ),
          ],
        ],
      ),
    );
  }
}
