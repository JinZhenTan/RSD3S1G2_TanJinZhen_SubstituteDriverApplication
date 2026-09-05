import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../account/providers/account_provider.dart';
import '../../booking/screens/payment_success_screen.dart';
import '../providers/car_service_provider.dart';

class ReviewPayScreen extends StatefulWidget {
  const ReviewPayScreen({super.key});

  @override
  State<ReviewPayScreen> createState() => _ReviewPayScreenState();
}

class _ReviewPayScreenState extends State<ReviewPayScreen> {
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarServiceProvider>();
    final account = context.watch<AccountProvider>();
    final r = state.active;

    if (r == null) {
      return const Scaffold(body: Center(child: Tr('No request')));
    }

    final items = state.itemisedFinalCost(r);
    final total = items.values.fold<double>(0, (s, v) => s + v);
    final paymentLabel = account.defaultPaymentMethod?.label ?? 'Cash';

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'VEHICLE CARE', title: 'Confirm & pay'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppStyles.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.serviceTypesLabel} — vehicle service',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Tr(
                        'Picked up from ${r.pickupAddress} · returned to you',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Tr(
                            'Payment method',
                            style: TextStyle(
                              color: Color(0xFF9AACC9),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            paymentLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 18),
                      for (final entry in items.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Tr(
                                entry.key,
                                style: const TextStyle(
                                  color: Color(0xFF9AACC9),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'RM ${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(color: Colors.white24, height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Tr(
                            'Total to pay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'RM ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.heroAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Pay RM ${total.toStringAsFixed(2)}',
                  icon: Icons.arrow_forward,
                  loading: _paying,
                  onPressed: () async {
                    final carService = context.read<CarServiceProvider>();
                    final account = context.read<AccountProvider>();
                    final navigator = Navigator.of(context);
                    setState(() => _paying = true);
                    await carService.payForService(r, paymentLabel);
                    await account.refreshReceipts();
                    if (!mounted) return;
                    setState(() => _paying = false);
                    navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PaymentSuccessScreen(
                          amount: total,
                          note:
                              'Paid for your car service — thanks for choosing '
                              'Ganti Vehicle Care.',
                          isBooking: false,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
