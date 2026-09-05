import 'package:flutter/material.dart';

import '../../../supabase_config.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/vehicle.dart';
import '../providers/account_provider.dart';

Future<Vehicle?> showVehicleFormSheet(
  BuildContext context,
  AccountProvider account, {
  Vehicle? existing,
}) {
  return showModalBottomSheet<Vehicle?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _VehicleFormSheet(existing: existing, account: account),
  );
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({this.existing, required this.account});

  final Vehicle? existing;
  final AccountProvider account;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _plate = TextEditingController(text: widget.existing?.plateNumber);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _colour = TextEditingController(text: widget.existing?.colour);
  late String _transmission = widget.existing?.transmission ?? 'Automatic';
  bool _saving = false;

  @override
  void dispose() {
    _plate.dispose();
    _model.dispose();
    _colour.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final account = widget.account;
    final existing = widget.existing;
    Vehicle saved;
    if (existing == null) {
      await account.addVehicle(
        Vehicle(
          id: 'pending',
          userId: supabase.auth.currentUser!.id,
          plateNumber: _plate.text.trim(),
          model: _model.text.trim(),
          colour: _colour.text.trim(),
          transmission: _transmission,
        ),
      );
      saved = account.vehicles.last;
    } else {
      saved = existing.copyWith(
        plateNumber: _plate.text.trim(),
        model: _model.text.trim(),
        colour: _colour.text.trim(),
        transmission: _transmission,
      );
      await account.updateVehicle(saved);
    }
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr(
              isEdit ? 'Edit vehicle' : 'Add a vehicle',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 16),
            _field(_plate, 'Plate number'),
            const SizedBox(height: 12),
            _field(_model, 'Model'),
            const SizedBox(height: 12),
            _field(_colour, 'Colour'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _transmission,
              decoration: InputDecoration(labelText: context.tr('Transmission')),
              items: const ['Automatic', 'Manual']
                  .map((t) => DropdownMenuItem(value: t, child: Tr(t)))
                  .toList(),
              onChanged: (val) => setState(() => _transmission = val ?? 'Automatic'),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: isEdit ? 'Save changes' : 'Add vehicle',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: context.tr(label)),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? context.tr('Required') : null,
    );
  }
}
