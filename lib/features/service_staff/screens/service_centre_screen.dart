import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../../../models/service_task.dart';
import '../providers/service_staff_provider.dart';
import 'service_staff_widgets.dart';

// Service staff role - PAGE 2 of 3: the service process, opened from the
// "Service" button on a job's card in the Requests tab (staff's home) once
// the car has reached the centre.
//   - tick each task off, add + price any extra work (owner approves)
//   - set an estimated ready time
//   - tap "Service complete - send car back" once done, which hands the job
//     over to PAGE 3 (ServiceReturnScreen) to actually drive the car home and
//     photograph its condition on return - this page has nothing to do with
//     the return trip itself, only the workshop side of things.
class ServiceCentreScreen extends StatefulWidget {
  const ServiceCentreScreen({super.key});

  @override
  State<ServiceCentreScreen> createState() => _ServiceCentreScreenState();
}

class _ServiceCentreScreenState extends State<ServiceCentreScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<ServiceStaffProvider>().subscribeToActive();
  }

  @override
  void dispose() {
    context.read<ServiceStaffProvider>().unsubscribeActive();
    super.dispose();
  }

  ServiceStaffProvider get _staff => context.read<ServiceStaffProvider>();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- ready-by ------------------------------------------------------
  Future<void> _editReadyBy() async {
    final r = _staff.active;
    if (r == null) return;
    final base = r.readyBy ?? DateTime.now().add(const Duration(hours: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    await _staff.setReadyBy(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  // ---- add extra work ---------------------------------------------
  Future<void> _addExtraTask() async {
    final titleC = TextEditingController();
    final detailC = TextEditingController();
    final priceC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Tr('Add extra work'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'What needs doing'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detailC,
              decoration: const InputDecoration(labelText: 'Detail (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (RM)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Tr('Send for approval'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final title = titleC.text.trim();
    final price = double.tryParse(priceC.text.trim()) ?? 0;
    if (title.isEmpty) return;
    await _staff.addExtraTask(
      title: title,
      detail: detailC.text.trim().isEmpty ? null : detailC.text.trim(),
      price: price,
    );
    _toast('Sent to the owner for approval');
  }

  // ---- advance ---------------------------------------------------
  Future<void> _advance() async {
    setState(() => _busy = true);
    await _staff.advanceStatus();
    if (!mounted) return;
    setState(() => _busy = false);
    // Service work is done - back to the Requests tab, where the "Return"
    // button is now unlocked.
    if (_staff.active?.status == CarServiceStatus.returning) {
      _toast('Marked as ready - the car is on its way back');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final r = staff.active;

    if (r == null) {
      return const Scaffold(body: Center(child: Tr('No job selected')));
    }

    // Once the car has left the centre (or is already back), the service
    // work itself is done - this page becomes a read-only summary and the
    // checklist can no longer be edited.
    final serviceDone = r.returningAt != null;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            eyebrow: serviceDone ? 'SERVICE COMPLETE' : 'AT THE SERVICE CENTRE',
            title: r.serviceTypesLabel,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 28 + MediaQuery.viewPaddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JobMap(staff: staff, request: r),
                const SizedBox(height: 14),
                CentreCard(staff: staff),
                const SizedBox(height: 12),
                CustomerCard(staff: staff, request: r),
                const SizedBox(height: 12),
                VehicleCard(car: staff.activeVehicle),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    sectionTitle('TASK CHECKLIST'),
                    Text(
                      '${staff.tasksDone}/${staff.tasks.length} · '
                      'RM ${staff.billableTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (staff.tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Tr('No tasks yet.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  )
                else
                  ...staff.tasks.map(
                    (t) => TaskRow(
                      task: t,
                      editable: !serviceDone,
                      onToggle: (v) => _staff.toggleTask(t, v),
                      onDelete: !serviceDone &&
                              t.isExtra &&
                              t.approval != TaskApproval.approved
                          ? () => _staff.deleteTask(t)
                          : null,
                    ),
                  ),
                const SizedBox(height: 4),
                if (!serviceDone)
                  OutlinedButton.icon(
                    onPressed: _addExtraTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Tr('Add extra work'),
                  ),
                const SizedBox(height: 16),

                if (!serviceDone) ...[
                  sectionTitle('ESTIMATED READY'),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: r.readyBy == null
                        ? 'Not set'
                        : DateFormat('EEE d MMM · h:mm a').format(r.readyBy!),
                    value: null,
                    onEdit: _editReadyBy,
                    icon: Icons.schedule,
                  ),
                  const SizedBox(height: 16),
                ],

                sectionTitle('STATUS'),
                const SizedBox(height: 8),
                StepRow(
                  label: 'At service centre',
                  done: serviceDone,
                  active: !serviceDone,
                ),
                StepRow(
                  label: 'On the way back',
                  done: false,
                  active: false,
                ),
                const SizedBox(height: 8),

                if (serviceDone)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.okSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Tr(
                      'Service complete — continue from the Return button '
                      'on the Requests tab.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ok,
                      ),
                    ),
                  )
                else ...[
                  PrimaryButton(
                    label: 'Service complete — send car back',
                    icon: Icons.arrow_forward,
                    loading: _busy,
                    onPressed: staff.canAdvance ? _advance : null,
                  ),
                  if (!staff.canAdvance && staff.advanceBlockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: AppColors.warn),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Tr(
                              staff.advanceBlockedReason!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.warn),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
