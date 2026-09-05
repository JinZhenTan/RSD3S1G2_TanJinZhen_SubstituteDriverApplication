import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../../account/providers/account_provider.dart';
import '../providers/service_staff_provider.dart';
import '../services/staff_earnings_exporter.dart';
import 'service_centre_screen.dart';
import 'service_pickup_screen.dart';
import 'service_return_screen.dart';

// Module 4 (service_staff role) - Earnings. Same layout as the driver role's
// Earnings screen: a basic salary + per-job earnings breakdown for a
// selected month (defaults to the current month), plus the job list behind
// the numbers.
class StaffEarningsScreen extends StatefulWidget {
  const StaffEarningsScreen({super.key});

  @override
  State<StaffEarningsScreen> createState() => _StaffEarningsScreenState();
}

class _StaffEarningsScreenState extends State<StaffEarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceStaffProvider>().loadEarningsForMonth(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final profile = context.watch<AccountProvider>().profile;
    final basicSalary = profile?.basicSalary ?? 800.0;
    final deductionRate = profile?.earningsDeductionRate ?? 0.10;
    final jobs = staff.completedMonthlyJobs;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Earnings'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => staff.loadEarningsForMonth(staff.earningsMonth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _MonthSelector(staff: staff),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: staff.earningsLoading
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
                                        'RM ${staff.netPay(basicSalary, deductionRate).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppColors.heroAccent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 26,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _ExportButton(jobs: jobs, month: staff.earningsMonth),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 26),
                              _NavyRow(
                                label: 'Basic salary',
                                value: 'RM ${basicSalary.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              _NavyRow(
                                label: 'Job earnings (${jobs.length} job${jobs.length == 1 ? '' : 's'})',
                                value: '+RM ${staff.jobEarnings.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              _NavyRow(
                                label: 'Deductions (platform fee ${(deductionRate * 100).toStringAsFixed(0)}%)',
                                value: '-RM ${staff.earningsDeductions(deductionRate).toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    child: Tr(
                      'JOBS THIS MONTH',
                      style: AppStyles.mono.copyWith(fontSize: 9.5),
                    ),
                  ),
                  if (!staff.earningsLoading && jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Tr(
                        'No completed jobs in this month yet.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                    ),
                  ...jobs.map((r) => _JobRow(request: r)),
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
  const _MonthSelector({required this.staff});

  final ServiceStaffProvider staff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: AppStyles.card,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: staff.showPreviousEarningsMonth,
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          Text(
            DateFormat('MMMM yyyy').format(staff.earningsMonth),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.ink,
            ),
          ),
          IconButton(
            onPressed: staff.canShowNextMonth ? staff.showNextEarningsMonth : null,
            icon: Icon(
              Icons.chevron_right,
              color: staff.canShowNextMonth ? AppColors.ink : AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

// The CSV/PDF export button on the earnings summary card - "a real export,
// not just a placeholder button" (CLAUDE.md), same requirement as the
// driver's trip log but for a service partner's completed jobs.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.jobs, required this.month});

  final List<CarServiceRequest> jobs;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final messenger = ScaffoldMessenger.of(context);
        if (jobs.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No completed jobs to export yet.')),
          );
          return;
        }
        if (value == 'csv') {
          await StaffEarningsExporter.exportCsv(jobs, month);
        } else {
          await StaffEarningsExporter.exportPdf(jobs, month);
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
    final amount = request.finalCost ?? request.costEstimateMin.toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                        Text(
                          '+RM ${amount.toStringAsFixed(2)}',
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
                      DateFormat('d MMM, h:mm a').format(request.createdAt),
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
