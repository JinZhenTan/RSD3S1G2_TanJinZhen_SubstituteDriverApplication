import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tr.dart';
import '../../account/providers/account_provider.dart';
import '../providers/booking_provider.dart';
import 'searching_screen.dart';

// Shared payment-success screen for both the booking flow and the car-service
// review-and-pay flow. `isBooking` decides whether the CTA continues to the
// driver search or returns home.
//
// For the booking flow, this is the deliberate second step of the "pay, then
// search" split (CLAUDE.md feedback): payment happened back on Confirm & Pay,
// but the booking row that makes the trip visible to drivers is only created
// here, when the passenger actively taps "Find my driver" - not as a side
// effect of paying.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.note,
    required this.isBooking,
  });

  final double amount;
  final String note;
  final bool isBooking;

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _starting = false;

  Future<void> _findDriver() async {
    setState(() => _starting = true);
    final booking = context.read<BookingProvider>();
    final saved = await booking.confirmAndPay();
    if (!mounted) return;

    if (saved == null) {
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the booking. Try again.')),
      );
      return;
    }

    // Refresh receipts so the Profile spend summary is current.
    context.read<AccountProvider>().refreshReceipts();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SearchingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.okSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.ok, size: 30),
              ),
              const SizedBox(height: 18),
              Tr(
                'Payment successful',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Tr(
                widget.note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              Text(
                'RM ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.blue700,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: widget.isBooking ? 'Find my driver' : 'Back to home',
                icon: widget.isBooking ? Icons.arrow_forward : null,
                loading: _starting,
                onPressed: () {
                  if (widget.isBooking) {
                    _findDriver();
                  } else {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
