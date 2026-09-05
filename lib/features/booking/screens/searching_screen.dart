import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../providers/booking_provider.dart';
import 'trip_tracking_screen.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  bool _offerDemo = false;
  Timer? _offerTimer;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      booking.addListener(_onBookingChanged);
      booking.subscribeToActiveBooking();
      _offerTimer = Timer(const Duration(seconds: 25), () {
        if (mounted) setState(() => _offerDemo = true);
      });
    });
  }

  void _onBookingChanged() {
    final booking = context.read<BookingProvider>();
    final matched = booking.tripStatus != BookingStatus.searching ||
        booking.activeDriver != null;
    if (matched && mounted) {
      booking.removeListener(_onBookingChanged);
      _offerTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TripTrackingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    try {
      context.read<BookingProvider>().removeListener(_onBookingChanged);
    } catch (_) {}
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = context.read<BookingProvider>().pickupAddress;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spin,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blue500,
                      width: 2,
                    ),
                    gradient: SweepGradient(
                      colors: [
                        AppColors.blue500.withValues(alpha: 0),
                        AppColors.blue500.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Tr(
                'Finding your driver…',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Tr(
                'Matching with substitute drivers near '
                '${pickup.isEmpty ? 'you' : pickup}. This usually takes under '
                '2 minutes.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.heroSubtext,
                  fontSize: 12,
                ),
              ),
              if (_offerDemo) ...[
                const SizedBox(height: 24),
                Tr(
                  'No drivers nearby yet.',
                  style: const TextStyle(
                    color: AppColors.heroSubtext,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _offerDemo = false);
                    context.read<BookingProvider>().runSimulationFallback();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.heroAccent,
                    side: BorderSide(color: AppColors.heroAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Tr('Continue with a demo driver'),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () async {
                  final booking = context.read<BookingProvider>();
                  final navigator = Navigator.of(context);
                  booking.removeListener(_onBookingChanged);
                  _offerTimer?.cancel();
                  await booking.cancelActiveBooking();
                  navigator.popUntil((r) => r.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Tr('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
