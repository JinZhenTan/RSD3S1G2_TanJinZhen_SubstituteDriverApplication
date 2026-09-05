import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../providers/booking_provider.dart';
import 'payment_success_screen.dart';

// Module 1 - Confirm & Pay. Read-only summary of the trip and fare, then the
// single "Pay & find driver" action that creates the booking row + receipt.
class ConfirmPayScreen extends StatefulWidget {
  const ConfirmPayScreen({super.key});

  @override
  State<ConfirmPayScreen> createState() => _ConfirmPayScreenState();
}

class _ConfirmPayScreenState extends State<ConfirmPayScreen> {
  // Paying and starting the search are two separate steps (CLAUDE.md
  // feedback): this screen only takes the payment. The booking row that
  // makes the trip visible to drivers isn't created until the passenger
  // explicitly taps "Find my driver" on the next screen - so a driver never
  // sees (or could react to) a request the passenger hasn't actively started
  // searching for yet.
  void _continue() {
    final booking = context.read<BookingProvider>();
    final fare = booking.fare;
    if (fare == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          amount: fare.total,
          note: 'Payment received. Tap below when you are ready to be '
              'matched with a driver.',
          isBooking: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final fare = booking.fare;
    final route = booking.tripRoute;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'FIND A DRIVER', title: 'Confirm & pay'),
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
                        '${booking.pickupAddress} → ${booking.destAddress}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${booking.tier.label}'
                        '${route == null ? '' : ' · ${route.distanceKm.toStringAsFixed(1)} km · approx. ${route.durationMinutes} min'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (fare != null)
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
                              booking.paymentLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 18),
                        for (final line in fare.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Tr(
                                    line.label,
                                    style: const TextStyle(
                                      color: Color(0xFF9AACC9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  'RM ${line.amount.toStringAsFixed(2)}',
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
                              'RM ${fare.total.toStringAsFixed(2)}',
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
                  label: fare == null
                      ? 'Pay & continue'
                      : 'Pay RM ${fare.total.toStringAsFixed(2)} & continue',
                  icon: Icons.arrow_forward,
                  onPressed: fare == null ? null : _continue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
