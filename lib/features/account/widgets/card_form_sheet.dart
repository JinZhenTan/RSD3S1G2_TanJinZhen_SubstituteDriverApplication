import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/payment_method.dart';
import '../providers/account_provider.dart';

// Real-world card entry: number, expiry, CVV, cardholder name. Only the last
// 4 digits and expiry are ever saved (see PaymentMethod's doc comment) - CVV
// is required on the form (as a real checkout would) but is read and
// discarded, never sent anywhere or stored.
//
// Shared by the Payment methods screen and the payment picker on Find a
// Driver, so a card can be added/edited from either place with the same form.
Future<void> showCardFormSheet(
  BuildContext context,
  AccountProvider account, {
  PaymentMethod? existing,
}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existing?.cardholderName);
  final numberController = TextEditingController(
    text: existing == null ? '' : '•••• •••• •••• ${existing.last4}',
  );
  final expiryController = TextEditingController(text: existing?.expiry);
  final cvvController = TextEditingController();
  final isEdit = existing != null;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr(
              isEdit ? 'Edit card details' : 'Add debit / credit card',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: sheetContext.tr('Cardholder name'),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? sheetContext.tr('Required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
              // Editing an existing card starts from the masked number - any
              // edit to it means a new card number, so it's re-validated as
              // fresh digits rather than kept as the old last4.
              onTap: isEdit && numberController.text.contains('•')
                  ? () => numberController.clear()
                  : null,
              decoration: InputDecoration(
                labelText: sheetContext.tr('Card number'),
                hintText: '4111 1111 1111 1111',
              ),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 12
                    ? sheetContext.tr('Enter a valid card number')
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                    decoration: InputDecoration(
                      labelText: sheetContext.tr('Expiry (MM/YY)'),
                      hintText: '08/29',
                    ),
                    validator: (v) =>
                        RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(v ?? '')
                            ? null
                            : sheetContext.tr('MM/YY'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: sheetContext.tr('CVV'),
                    ),
                    validator: (v) =>
                        (v ?? '').length < 3 ? sheetContext.tr('CVV') : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Tr(
              'Your card number and CVV are never stored - only the last 4 '
              'digits and expiry are saved.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final digits =
                      numberController.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final last4 = digits.length >= 4
                      ? digits.substring(digits.length - 4)
                      : digits.padLeft(4, '0');
                  final navigator = Navigator.of(sheetContext);
                  if (isEdit) {
                    await account.updatePaymentMethod(existing.copyWith(
                      label: 'Card •••• $last4',
                      last4: last4,
                      expiry: expiryController.text.trim(),
                      cardholderName: nameController.text.trim(),
                    ));
                  } else {
                    await account.addPaymentMethod(
                      'card',
                      'Card •••• $last4',
                      last4: last4,
                      expiry: expiryController.text.trim(),
                      cardholderName: nameController.text.trim(),
                    );
                  }
                  navigator.pop();
                },
                child: Tr(isEdit ? 'Save changes' : 'Add card'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Auto-inserts the "/" as the user types MMYY digits.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits =
        newValue.text.replaceAll(RegExp(r'[^0-9]'), '').substring(
              0,
              newValue.text.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 4),
            );
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
