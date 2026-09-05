import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/vehicle.dart';
import '../../account/providers/account_provider.dart';
import '../../account/widgets/vehicle_form_sheet.dart';
import '../providers/car_service_provider.dart';
import 'select_location_screen.dart';
import 'select_service_type_screen.dart';
import 'status_tracker_screen.dart';

class CarServiceFormScreen extends StatefulWidget {
  const CarServiceFormScreen({super.key});

  @override
  State<CarServiceFormScreen> createState() => _CarServiceFormScreenState();
}

class _CarServiceFormScreenState extends State<CarServiceFormScreen> {
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _notesController.text = context.read<CarServiceProvider>().notes;
    final account = context.read<AccountProvider>();
    _phoneController.text = account.profile?.phone ?? '';
    _selectedVehicle = account.defaultVehicle;
  }

  Future<void> _pickVehicle() async {
    final account = context.read<AccountProvider>();
    final chosen = await showModalBottomSheet<Vehicle>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Tr(
                'Which vehicle?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            for (final v in account.vehicles)
              ListTile(
                leading: const Icon(Icons.directions_car_outlined,
                    color: AppColors.blue600),
                title: Text(v.modelAndColour),
                subtitle: Text(v.plateNumber),
                trailing: v.id == _selectedVehicle?.id
                    ? const Icon(Icons.check, color: AppColors.blue600)
                    : null,
                onTap: () => Navigator.pop(sheetContext, v),
              ),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.blue600),
              title: const Tr('Add a vehicle'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final added = await showVehicleFormSheet(context, account);
                if (added != null && mounted) {
                  setState(() => _selectedVehicle = added);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _selectedVehicle = chosen);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final state = context.read<CarServiceProvider>();
    final now = DateTime.now();
    final initial =
        state.pickupDateTime.isBefore(now) ? now : state.pickupDateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(state.pickupDateTime),
    );
    if (time == null || !mounted) return;
    state.setDateTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _submit() async {
    final state = context.read<CarServiceProvider>();
    final account = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      if (_selectedVehicle == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Select which vehicle this booking is for.'),
        ));
        return;
      }

      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Add a contact number so the driver can reach you.'),
        ));
        return;
      }
      if ((account.profile?.phone ?? '').trim() != phone) {
        await account.updateProfile(
          name: account.profile?.name ?? 'Guest',
          phone: phone,
        );
      }

      if (state.pickupAddress.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Select a pick-up location.'),
        ));
        return;
      }

      if (state.pickupPoint == null) {
        final results = await GeocodingService().search(state.pickupAddress);
        if (results.isNotEmpty) {
          state.setPickup(state.pickupAddress, results.first.position);
        }
      }
      if (state.pickupPoint == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
            'Could not pin that pick-up address. Set it from the map or GPS.',
          ),
        ));
        return;
      }

      state.setNotes(_notesController.text);
      final saved = await state.submitRequest(_selectedVehicle);
      if (!mounted) return;
      if (saved == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Could not submit the request.'),
        ));
        return;
      }
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const StatusTrackerScreen()),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarServiceProvider>();
    final vehicle = _selectedVehicle;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'VEHICLE CARE', title: 'Car service'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    border: Border.all(color: AppColors.blue100),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Tr(
                    'Our company driver collects your car from you, takes it to '
                    'the workshop, and returns it once done — you don\'t need '
                    'to be there.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.blue700),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: AppStyles.card,
                  child: Column(
                    children: [
                      _FormRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'PICK-UP DATE & TIME',
                        value: DateFormat('EEE, d MMM · h:mm a')
                            .format(state.pickupDateTime),
                        onTap: _pickDateTime,
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _FormRow(
                        icon: Icons.circle,
                        iconColor: AppColors.ok,
                        label: 'PICK-UP LOCATION',
                        value: state.pickupAddress.isEmpty
                            ? 'Select pick-up location'
                            : state.pickupAddress,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SelectLocationScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _FormRow(
                        icon: Icons.build_outlined,
                        label: 'SERVICE TYPE',
                        value: state.serviceTypes.map((t) => t.label).join(', '),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SelectServiceTypeScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: AppStyles.card,
                  child: Column(
                    children: [
                      _FormRow(
                        icon: Icons.directions_car_outlined,
                        label: 'VEHICLE',
                        value: vehicle == null
                            ? 'Add a vehicle - required to continue'
                            : '${vehicle.plateNumber} · ${vehicle.modelAndColour}',
                        onTap: _pickVehicle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Contact number'),
                    hintText: '+60...',
                    prefixIcon: const Icon(Icons.call_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                const Tr(
                  'The service partner uses this to reach you about your car.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Tr(
                            'Estimated cost',
                            style: TextStyle(
                              color: Color(0xFF9AACC9),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'RM ${state.estimateMin}',
                            style: const TextStyle(
                              color: AppColors.heroAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Tr(
                          'Pay after return',
                          style: TextStyle(
                            color: AppColors.heroAccent,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Tr(
                  'The final price depends on parts and labour needed. You\'ll '
                  'review the exact cost and pay once your car has been serviced '
                  'and returned to you.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: context.tr(
                        'Additional notes for the driver — e.g. "Key with the '
                        'guardhouse" or "Check the AC while it\'s in".'),
                    hintMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Confirm pick-up request',
                  icon: Icons.arrow_forward,
                  loading: _submitting,
                  onPressed: vehicle == null ? null : _submit,
                ),
                if (vehicle == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Tr(
                      'Add your vehicle details in Profile → My vehicle details '
                      'before booking a service.',
                      style: TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.iconColor = AppColors.blue600,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(label, style: AppStyles.mono.copyWith(fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.muted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
