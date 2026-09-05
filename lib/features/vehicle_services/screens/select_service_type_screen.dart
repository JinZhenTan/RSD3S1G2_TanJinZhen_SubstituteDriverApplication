import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../providers/car_service_provider.dart';

class SelectServiceTypeScreen extends StatelessWidget {
  const SelectServiceTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarServiceProvider>();

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'VEHICLE CARE', title: 'Service type'),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: CarServiceType.all.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, i) {
                final type = CarServiceType.all[i];
                final selected = state.serviceTypes.contains(type);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  onChanged: (_) => context
                      .read<CarServiceProvider>()
                      .toggleServiceType(type),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Tr(
                    type.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('RM ${type.price}'),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 16 + MediaQuery.viewPaddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: AppColors.page,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tr(
                      '${state.serviceTypes.length} selected',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    Text(
                      'RM ${state.estimateMin}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blue700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
