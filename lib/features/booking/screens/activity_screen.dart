import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../core/widgets/unread_dot.dart';
import '../../../models/booking.dart';
import '../../../models/car_service_request.dart';
import '../../vehicle_services/screens/status_tracker_screen.dart';
import '../../vehicle_services/providers/car_service_provider.dart';
import '../providers/booking_provider.dart';
import 'trip_detail_screen.dart';
import 'trip_tracking_screen.dart';

// Module 1 - Activity tab (view-activity in the prototype). Trip history +
// driver chats, plus car-service jobs, with an All / In progress / Completed
// filter.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _filter = 0; // 0 = all, 1 = in progress, 2 = completed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadActivity();
      context.read<CarServiceProvider>().loadRequests();
    });
  }

  bool _bookingMatches(Booking b) {
    if (_filter == 0) return true;
    final inProgress = b.status != BookingStatus.completed &&
        b.status != BookingStatus.cancelled;
    return _filter == 1 ? inProgress : !inProgress;
  }

  bool _serviceMatches(CarServiceRequest r) {
    if (_filter == 0) return true;
    final done = r.isCancelled ||
        (r.status == CarServiceStatus.returned && r.paymentStatus == 'paid');
    return _filter == 1 ? !done : done;
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final carService = context.watch<CarServiceProvider>();

    final bookings = booking.pastBookings.where(_bookingMatches).toList();
    final services = carService.requests.where(_serviceMatches).toList();

    return Container(
      color: AppColors.page,
      child: RefreshIndicator(
        onRefresh: () async {
          await booking.loadActivity();
          await carService.loadRequests();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr(
                      'TRIPS & DRIVER CHATS',
                      style: AppStyles.eyebrow,
                    ),
                    const SizedBox(height: 6),
                    Tr(
                      'Activity',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: _Segmented(
                labels: [
                  context.tr('All'),
                  context.tr('In progress'),
                  context.tr('Completed'),
                ],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ),
            if (bookings.isEmpty && services.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Tr(
                    'Nothing here yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            ...bookings.map((b) => _BookingRow(booking: b)),
            ...services.map((r) => _ServiceRow(request: r)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: i == index ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});

  final Booking booking;

  // A booking row can belong to the signed-in account as either the
  // passenger or (if they also drove it) the driver - see loadActivity's
  // comment. Needed so UnreadDot checks messages from the *other* side.
  String? get _myUserId => supabase.auth.currentUser?.id;

  // A finished trip is a static, read-only summary. A trip still in progress
  // opens the live Trip Tracking screen instead - the map, ETA, and (once the
  // driver reports arrival) the "Confirm trip completed" button all need the
  // booking to keep updating live, which the read-only detail screen does not
  // do.
  Future<void> _open(BuildContext context) async {
    if (bookingIsHistory(booking.status)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(booking: booking)),
      );
      return;
    }
    await context.read<BookingProvider>().resumeTrip(booking);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TripTrackingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHistory = bookingIsHistory(booking.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppStyles.card,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isHistory ? AppColors.blue50 : AppColors.okSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: isHistory ? AppColors.blue600 : AppColors.ok,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            booking.routeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        UnreadDot(
                          bookingId: booking.id,
                          mySenderType: booking.driverId == _myUserId
                              ? 'driver'
                              : 'user',
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('d MMM').format(booking.createdAt),
                          style: AppStyles.mono.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.serviceTier.label} · ${bookingStatusLabel(booking.status)} · '
                      'RM ${(booking.fareFinal ?? booking.fareEstimate).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.request});

  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: InkWell(
        onTap: () {
          context.read<CarServiceProvider>().selectRequest(request);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StatusTrackerScreen()),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppStyles.card,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.okSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.build, color: AppColors.ok, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Car service · ${request.serviceTypesLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        UnreadDot(
                          serviceRequestId: request.id,
                          mySenderType: 'user',
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('d MMM').format(request.createdAt),
                          style: AppStyles.mono.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${carServiceStatusLabel(request.status)} · ${request.paymentStatus}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
