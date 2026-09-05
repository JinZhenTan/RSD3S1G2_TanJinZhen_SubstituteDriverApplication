import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/payment_method.dart';
import '../providers/account_provider.dart';
import '../widgets/card_form_sheet.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final methods = account.paymentMethods;
    PaymentMethod? byType(String type) {
      for (final m in methods) {
        if (m.type == type) return m;
      }
      return null;
    }

    final cash = byType('cash');
    final ewallet = byType('ewallet');
    final card = byType('card');

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Payment methods'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                if (cash != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppStyles.card,
                    child: _PaymentRow(method: cash),
                  ),
                if (ewallet != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppStyles.card,
                    child: _PaymentRow(method: ewallet),
                  ),
                if (card != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppStyles.card,
                    child: _PaymentRow(
                      method: card,
                      onEdit: () =>
                          showCardFormSheet(context, account, existing: card),
                      onRemove: () => _removeWithConfirm(context, card),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => showCardFormSheet(context, account),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: AppStyles.card,
                      child: const Row(
                        children: [
                          Icon(Icons.credit_card, color: AppColors.blue600, size: 18),
                          SizedBox(width: 12),
                          Tr(
                            'Add card details',
                            style: TextStyle(
                              color: AppColors.blue600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Tr(
                  'Tap a method to make it the default for your bookings',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeWithConfirm(BuildContext context, PaymentMethod method) async {
    if (await _confirmDelete(context, method)) {
      if (!context.mounted) return;
      await context.read<AccountProvider>().removePaymentMethod(method);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, PaymentMethod method) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Remove payment method?'),
        content: Text('${method.label} will be removed from your account.'),
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
    return result ?? false;
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    this.onEdit,
    this.onRemove,
  });

  final PaymentMethod method;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.read<AccountProvider>().setDefaultPaymentMethod(method),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 26,
              decoration: BoxDecoration(
                color: method.type == 'ewallet'
                    ? AppColors.blue600
                    : method.type == 'cash'
                        ? AppColors.ok
                        : AppColors.navy,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                method.badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if (method.expiry != null)
                    Text(
                      'Expires ${method.expiry}',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (method.isDefault)
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
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.muted),
                onPressed: onEdit,
                tooltip: context.tr('Edit'),
              ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, size: 17, color: AppColors.muted),
                onPressed: onRemove,
                tooltip: context.tr('Remove'),
              ),
          ],
        ),
      ),
    );
  }
}
