import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/vehicle.dart';
import '../providers/account_provider.dart';
import '../widgets/vehicle_form_sheet.dart';

class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final vehicles = account.vehicles;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'ACCOUNT', title: 'My vehicles'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                if (vehicles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Tr(
                      'No vehicles yet. Add the car a substitute driver will '
                      'drive, or that car service will collect.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final v in vehicles) _VehicleCard(vehicle: v),
                if (vehicles.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 4),
                    child: Tr(
                      'Tap a car to make it the default',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                const SizedBox(height: 10),
                GhostButton(
                  label: 'Add a vehicle',
                  onPressed: () => showVehicleFormSheet(context, account),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppStyles.card,
      child: InkWell(
        onTap: () => context.read<AccountProvider>().setDefaultVehicle(vehicle),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car,
                    color: AppColors.blue600, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.modelAndColour,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${vehicle.plateNumber} · ${vehicle.transmission}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (vehicle.isDefault)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Tr(
                    'Default',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue600,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.muted),
                tooltip: context.tr('Edit'),
                onPressed: () => showVehicleFormSheet(
                  context,
                  context.read<AccountProvider>(),
                  existing: vehicle,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 17, color: AppColors.muted),
                tooltip: context.tr('Remove'),
                onPressed: () => _confirmRemove(context, vehicle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Vehicle vehicle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Remove this vehicle?'),
        content: Text('${vehicle.modelAndColour} will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Tr('Remove'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await context.read<AccountProvider>().removeVehicle(vehicle);
    }
  }
}
