import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../../models/vehicle.dart';
import '../providers/driver_provider.dart';
import 'driver_job_detail_screen.dart';

// Driver role - the accept queue, opened from the "Available bookings" tile
// on the driver Home screen. Shows the driver's active booking (if any) and
// the list of unassigned booking requests they can accept.
class DriverJobsScreen extends StatelessWidget {
  const DriverJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final ended = driver.jobEndedByPassenger;

    return Scaffold(
      appBar: AppBar(title: const Tr('Available bookings')),
      body: Container(
        color: AppColors.page,
        child: RefreshIndicator(
          onRefresh: () => driver.loadJobs(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              if (ended != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _EndedNotice(booking: ended),
                ),
              if (driver.activeJob != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Tr('Your active booking', style: AppStyles.sectionTitle),
                ),
                _ActiveJobCard(job: driver.activeJob!),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child:
                    Tr('Available requests', style: AppStyles.sectionTitle),
              ),
              if (driver.isLoading && driver.availableJobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (driver.availableJobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Tr(
                      'No booking requests right now. Pull to refresh.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              ...driver.availableJobs.map((job) => _RequestCard(job: job)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Dismissible banner shown when the passenger ended the active booking from
// their side (cancelled it, or confirmed completion) while this driver
// wasn't looking at the booking's own detail screen.
class _EndedNotice extends StatelessWidget {
  const _EndedNotice({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final cancelled = booking.status == BookingStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cancelled ? AppColors.dangerSoft : AppColors.okSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
            size: 18,
            color: cancelled ? AppColors.danger : AppColors.ok,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tr(
              cancelled
                  ? 'Your last booking was cancelled by the passenger'
                  : 'The passenger confirmed your last booking is complete',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cancelled ? AppColors.danger : AppColors.ok,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 16, color: cancelled ? AppColors.danger : AppColors.ok),
            onPressed: () => context.read<DriverProvider>().acknowledgeJobNotice(),
          ),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job});

  final Booking job;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DriverJobDetailScreen()),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.routeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Tr(
                '${_statusLabel(job.status)} · tap to open',
                style: const TextStyle(
                  color: AppColors.heroAccent,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.enRoute:
        return 'Heading to pickup';
      case BookingStatus.onTrip:
        return 'Driving now';
      case BookingStatus.arrived:
        return 'Waiting for passenger to confirm';
      default:
        return s.name;
    }
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.job});

  final Booking job;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _accepting = false;
  // Tapped on the map below - lets the driver set where they're starting
  // from instead of relying on device GPS, so the app is easy to demo (a
  // laptop or emulator has no real GPS near the pickup point). Null means
  // "use my real location when I accept".
  LatLng? _myLocation;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final driver = context.read<DriverProvider>();
    final ok = await driver.acceptJob(widget.job, manualStart: _myLocation);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DriverJobDetailScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That booking was already taken.')),
      );
      driver.loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.routeLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${job.serviceTier.label} · '
            '${DateFormat('d MMM, h:mm a').format(job.createdAt)} · '
            'fare RM ${job.fareEstimate.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          _VehiclePreview(vehicleId: job.vehicleId),
          const SizedBox(height: 10),
          // The passenger's current pickup point plus the destination, so a
          // driver can judge the pickup distance and trip direction before
          // committing - not just read two addresses as text. Tapping the
          // map sets a starting point for this job instead of using device
          // GPS (handy when presenting/demoing away from the real pickup).
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MapView(
              centre: _myLocation ?? LatLng(job.pickupLat, job.pickupLng),
              markers: [
                MapView.dot(LatLng(job.pickupLat, job.pickupLng), AppColors.ok),
                MapView.pin(LatLng(job.destLat, job.destLng), AppColors.danger),
                if (_myLocation != null)
                  MapView.pin(_myLocation!, AppColors.blue600,
                      icon: Icons.navigation),
              ],
              height: 130,
              zoom: 12,
              interactive: true,
              onTap: (point) => setState(() => _myLocation = point),
            ),
          ),
          const SizedBox(height: 6),
          MapLegend(items: [
            const MapLegendItem(AppColors.ok, 'Passenger'),
            const MapLegendItem(AppColors.danger, 'Destination'),
            if (_myLocation != null)
              const MapLegendItem(AppColors.blue600, 'You (tapped)'),
          ]),
          const SizedBox(height: 4),
          Tr(
            _myLocation == null
                ? 'Tap the map to set your starting point (optional - uses '
                    'your real location otherwise)'
                : 'Starting point set. Tap the map again to change it.',
            style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Tr('Accept booking'),
            ),
          ),
        ],
      ),
    );
  }
}

// Shows which car this booking is for before the driver even accepts, not
// just after - so they know what to look for (plate, model, colour) while
// deciding, and can spot it more easily once they arrive. RLS lets any
// signed-in account read a vehicle row (drivers need to see the passenger's
// car), so this is a plain one-off lookup per card.
class _VehiclePreview extends StatefulWidget {
  const _VehiclePreview({required this.vehicleId});

  final String? vehicleId;

  @override
  State<_VehiclePreview> createState() => _VehiclePreviewState();
}

class _VehiclePreviewState extends State<_VehiclePreview> {
  Vehicle? _vehicle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.vehicleId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await supabase.from('vehicles').select().eq('id', id).maybeSingle();
      if (!mounted) return;
      setState(() {
        _vehicle = row == null ? null : Vehicle.fromJson(row);
        _loading = false;
      });
    } catch (e) {
      print('_VehiclePreview load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final v = _vehicle;
    // Older bookings made before vehicle selection was required may have no
    // vehicle_id - fall back to a neutral notice rather than showing nothing.
    if (v == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Tr(
          'Vehicle details not provided - confirm with the passenger at pick-up',
          style: TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, size: 15, color: AppColors.blue600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${v.plateNumber} · ${v.modelAndColour} · ${v.transmission}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.blue700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
