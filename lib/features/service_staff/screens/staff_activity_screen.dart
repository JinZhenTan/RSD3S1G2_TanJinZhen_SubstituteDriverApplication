import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../providers/service_staff_provider.dart';
import 'service_centre_screen.dart';
import 'service_pickup_screen.dart';
import 'service_return_screen.dart';

// Service staff role - Profile > Activity. Same look as the passenger/
// driver Activity tab (navy header + All / In progress / Completed segmented
// filter + card rows) but showing the staff's own work history - the car
// service jobs they've accepted - instead of trip bookings or receipts.
class StaffActivityScreen extends StatefulWidget {
  const StaffActivityScreen({super.key});

  @override
  State<StaffActivityScreen> createState() => _StaffActivityScreenState();
}

class _StaffActivityScreenState extends State<StaffActivityScreen> {
  int _filter = 0; // 0 = all, 1 = in progress, 2 = completed

  bool _matches(CarServiceRequest r) {
    if (_filter == 0) return true;
    final done = r.isCancelled || r.status == CarServiceStatus.returned;
    return _filter == 1 ? !done : done;
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final myId = staff.currentUserId;
    // Only jobs actually accepted by this staff member - not the open queue.
    final jobs = staff.requests
        .where((r) => r.driverId == myId)
        .where(_matches)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => staff.loadRequests(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ScreenHeader(eyebrow: 'CAR SERVICE PARTNER', title: 'Activity'),
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
            if (jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Tr(
                    'Nothing here yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            ...jobs.map((r) => _JobRow(request: r)),
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

class _JobRow extends StatelessWidget {
  const _JobRow({required this.request});

  final CarServiceRequest request;

  void _open(BuildContext context) {
    context.read<ServiceStaffProvider>().selectRequest(request);
    final Widget screen;
    if (request.status == CarServiceStatus.returning ||
        request.status == CarServiceStatus.returned) {
      screen = const ServiceReturnScreen();
    } else if (request.status == CarServiceStatus.atCentre) {
      screen = const ServiceCentreScreen();
    } else {
      screen = const ServicePickupScreen();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final done = request.isCancelled ||
        request.status == CarServiceStatus.returned;
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
                  color: done ? AppColors.blue50 : AppColors.okSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.build,
                  color: done ? AppColors.blue600 : AppColors.ok,
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
                            request.serviceTypesLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
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
                      '${carServiceStatusLabel(request.status, forStaff: true)} · ${request.pickupAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
