import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../account/providers/account_provider.dart';
import '../../booking/screens/trip_detail_screen.dart';
import '../providers/driver_provider.dart';
import '../services/earnings_exporter.dart';
import 'driver_job_detail_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadEarningsForMonth(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final profile = context.watch<AccountProvider>().profile;
    final basicSalary = profile?.basicSalary ?? 0.0;
    final deductionRate = profile?.earningsDeductionRate ?? 0.0;
    final trips = driver.completedMonthlyTrips;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Earnings'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => driver.loadEarningsForMonth(driver.earningsMonth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _MonthSelector(driver: driver),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: driver.earningsLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Tr(
                                        'Net pay this month',
                                        style: TextStyle(
                                          color: Color(0xFF9AACC9),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'RM ${driver.netPay(basicSalary, deductionRate).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppColors.heroAccent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 26,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _ExportButton(trips: trips, month: driver.earningsMonth),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 26),
                              _NavyRow(
                                label: 'Basic salary',
                                value: 'RM ${basicSalary.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              _NavyRow(
                                label: 'Booking earnings (${trips.length} booking${trips.length == 1 ? '' : 's'})',
                                value: '+RM ${driver.tripEarnings.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              _NavyRow(
                                label: 'Deductions (platform fee ${(deductionRate * 100).toStringAsFixed(0)}%)',
                                value: '-RM ${driver.earningsDeductions(deductionRate).toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    child: Tr(
                      'BOOKINGS THIS MONTH',
                      style: AppStyles.mono.copyWith(fontSize: 9.5),
                    ),
                  ),
                  if (!driver.earningsLoading && trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Tr(
                        'No completed bookings in this month yet.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                    ),
                  ...trips.map((b) => _TripRow(booking: b)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.driver});

  final DriverProvider driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: AppStyles.card,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: driver.showPreviousEarningsMonth,
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          Text(
            DateFormat('MMMM yyyy').format(driver.earningsMonth),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.ink,
            ),
          ),
          IconButton(
            onPressed: driver.canShowNextMonth ? driver.showNextEarningsMonth : null,
            icon: Icon(
              Icons.chevron_right,
              color: driver.canShowNextMonth ? AppColors.ink : AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.trips, required this.month});

  final List<Booking> trips;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final messenger = ScaffoldMessenger.of(context);
        if (trips.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No completed bookings to export yet.')),
          );
          return;
        }
        if (value == 'csv') {
          await EarningsExporter.exportCsv(trips, month);
        } else {
          await EarningsExporter.exportPdf(trips, month);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'csv', child: Tr('Export as CSV')),
        PopupMenuItem(value: 'pdf', child: Tr('Export as PDF')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.blue600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Tr(
          'Export ⤓',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

class _NavyRow extends StatelessWidget {
  const _NavyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Tr(
            label,
            style: const TextStyle(color: Color(0xFF9AACC9), fontSize: 12),
          ),
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          final stillActive = !bookingIsHistory(booking.status) &&
              context.read<DriverProvider>().activeJob?.id == booking.id;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => stillActive
                  ? const DriverJobDetailScreen()
                  : TripDetailScreen(booking: booking),
            ),
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
                child: const Icon(Icons.payments_outlined, color: AppColors.ok, size: 18),
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
                        Text(
                          '+RM ${(booking.fareFinal ?? booking.fareEstimate).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ok,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.serviceTier.label} · ${DateFormat('d MMM, h:mm a').format(booking.createdAt)}',
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
