import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/location_search_screen.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/booking.dart';
import '../../../models/payment_method.dart';
import '../../../models/place.dart';
import '../../../models/vehicle.dart';
import '../../account/providers/account_provider.dart';
import '../../account/widgets/card_form_sheet.dart';
import '../../account/widgets/vehicle_form_sheet.dart';
import '../../weather_safety/providers/weather_provider.dart';
import '../providers/booking_provider.dart';
import 'confirm_pay_screen.dart';

// Module 1 - Find a Driver. Service-tier chips, pickup/destination fields, an
// OSM map with the trip route, and the live fare breakdown.
class FindDriverScreen extends StatefulWidget {
  const FindDriverScreen({super.key});

  @override
  State<FindDriverScreen> createState() => _FindDriverScreenState();
}

class _FindDriverScreenState extends State<FindDriverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prime());
  }

  // Only pre-fill the payment method / vehicle defaults - never the pickup
  // or destination. The passenger always sets those two themselves (current
  // location or search, via _pickLocation below), never a silently-chosen
  // example address.
  Future<void> _prime() async {
    final booking = context.read<BookingProvider>();
    final acc = context.read<AccountProvider>();
    booking.setPaymentLabel(acc.defaultPaymentMethod?.label ?? 'Cash');
    if (booking.selectedVehicle == null && acc.defaultVehicle != null) {
      booking.setVehicle(acc.defaultVehicle!);
    }
  }

  // Always actionable, even with zero vehicles registered - a passenger
  // shouldn't have to leave the booking flow and go to Profile just to add
  // their first car. Same picker either way; "Add a vehicle" is always the
  // last option.
  Future<void> _pickVehicle() async {
    final account = context.read<AccountProvider>();
    final booking = context.read<BookingProvider>();
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
                trailing: v.id == booking.selectedVehicle?.id
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
                  context.read<BookingProvider>().setVehicle(added);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      context.read<BookingProvider>().setVehicle(chosen);
    }
  }

  Future<void> _pickLocation({required bool isPickup}) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          eyebrow: 'FIND A DRIVER',
          title: isPickup ? 'Your location' : 'Destination',
          allowCurrentLocation: isPickup,
        ),
      ),
    );
    if (place == null || !mounted) return;
    final booking = context.read<BookingProvider>();
    final weather = context.read<WeatherProvider>();
    if (isPickup) {
      booking.setPickup(place.position, place.shortName);
    } else {
      booking.setDestination(place.position, place.shortName);
    }
    await booking.recalculateWithAlerts(weather.alerts);
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final weather = context.watch<WeatherProvider>();
    final hasRainAdvisory = weather.safetyAlerts.isNotEmpty;

    final centre = booking.pickup ?? const LatLng(5.4141, 100.3288);
    final markers = <Marker>[
      if (booking.pickup != null) MapView.dot(booking.pickup!, AppColors.ok),
      if (booking.destination != null)
        MapView.pin(booking.destination!, AppColors.danger),
    ];

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            eyebrow: hasRainAdvisory
                ? '⚠ Rain advisory active on nearby routes'
                : 'FIND A DRIVER',
            title: 'Find a driver',
          ),
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
                    'A verified driver comes to your location and drives your '
                    'own car to your destination. You ride along — no need to '
                    'leave your car behind.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.blue700),
                  ),
                ),
                const SizedBox(height: 16),
                _TierChips(
                  selected: booking.tier,
                  onSelected: (t) {
                    context.read<BookingProvider>().setTier(t);
                    context
                        .read<BookingProvider>()
                        .recalculateWithAlerts(weather.alerts);
                  },
                ),
                const SizedBox(height: 8),
                _TierDescription(tier: booking.tier),
                const SizedBox(height: 16),
                _FieldCard(
                  pickup: booking.pickupAddress,
                  destination: booking.destAddress,
                  onEditPickup: () => _pickLocation(isPickup: true),
                  onEditDestination: () => _pickLocation(isPickup: false),
                ),
                const SizedBox(height: 12),
                _VehicleRow(
                  vehicle: booking.selectedVehicle,
                  onTap: _pickVehicle,
                ),
                const SizedBox(height: 16),
                if (booking.tripRoute != null) ...[
                  MapView(
                    centre: centre,
                    routePoints: booking.tripRoute!.points,
                    markers: markers,
                    height: 200,
                  ),
                  const SizedBox(height: 8),
                  const MapLegend(items: [
                    MapLegendItem(AppColors.ok, 'Your car'),
                    MapLegendItem(AppColors.danger, 'Destination'),
                  ]),
                ] else
                  Container(
                    height: 200,
                    decoration: AppStyles.card,
                    alignment: Alignment.center,
                    child: booking.routeLoading
                        ? const CircularProgressIndicator()
                        : const Tr('Set pickup & destination'),
                  ),
                const SizedBox(height: 16),
                _FareSummary(
                  booking: booking,
                  onChangePayment: _openPaymentPicker,
                ),
                const SizedBox(height: 8),
                if (booking.isDraftComplete &&
                    booking.fare != null &&
                    booking.selectedVehicle == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Tr(
                      'Select which vehicle this booking is for to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.warn),
                    ),
                  ),
                PrimaryButton(
                  label: 'Find my driver',
                  icon: Icons.arrow_forward,
                  onPressed: booking.isDraftComplete &&
                          booking.fare != null &&
                          booking.selectedVehicle != null
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ConfirmPayScreen(),
                            ),
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _PaymentSheet(),
    );
    if (selected != null && mounted) {
      context.read<BookingProvider>().setPaymentLabel(selected);
    }
  }
}

class _TierChips extends StatelessWidget {
  const _TierChips({required this.selected, required this.onSelected});

  final ServiceTier selected;
  final ValueChanged<ServiceTier> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ServiceTier.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final tier = ServiceTier.all[i];
          final isSel = tier == selected;
          return GestureDetector(
            onTap: () => onSelected(tier),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? AppColors.blue50 : AppColors.card,
                border: Border.all(
                  color: isSel ? AppColors.blue600 : AppColors.line,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tr(
                    tier.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isSel ? AppColors.blue700 : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Tr(
                    tier.rateLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isSel ? AppColors.blue700 : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Explains what the currently-selected chip in _TierChips means. Swaps as the
// passenger taps between tiers so the choice never needs a separate info
// screen.
class _TierDescription extends StatelessWidget {
  const _TierDescription({required this.tier});

  final ServiceTier tier;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 14, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tr(
            tier.description,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// Which of the passenger's (possibly several) cars the driver will drive -
// required before paying (see the "Find my driver" button's onPressed).
// Always tappable, even with zero vehicles registered: the picker itself
// offers "Add a vehicle" inline, so there's no detour to Profile.
class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle, required this.onTap});

  final Vehicle? vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = vehicle == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: missing
            ? BoxDecoration(
                color: AppColors.warnSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
              )
            : AppStyles.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              missing ? Icons.add_circle_outline : Icons.directions_car_outlined,
              color: missing ? AppColors.warn : AppColors.blue600,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
                    'VEHICLE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: missing ? AppColors.warn : AppColors.muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    missing
                        ? context.tr('Add a vehicle - required to continue')
                        : '${vehicle!.plateNumber} · ${vehicle!.modelAndColour}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: missing ? AppColors.warn : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: missing ? AppColors.warn : AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.pickup,
    required this.destination,
    required this.onEditPickup,
    required this.onEditDestination,
  });

  final String pickup;
  final String destination;
  final VoidCallback onEditPickup;
  final VoidCallback onEditDestination;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppStyles.card,
      child: Column(
        children: [
          _row(
            context: context,
            colour: AppColors.ok,
            label: 'YOUR LOCATION (WITH CAR)',
            value: pickup.isEmpty ? context.tr('Tap to set') : pickup,
            onTap: onEditPickup,
          ),
          const Divider(height: 1, color: AppColors.line),
          _row(
            context: context,
            colour: AppColors.danger,
            label: 'DESTINATION',
            value: destination.isEmpty ? context.tr('Tap to set') : destination,
            onTap: onEditDestination,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required BuildContext context,
    required Color colour,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(label, style: AppStyles.mono.copyWith(fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FareSummary extends StatelessWidget {
  const _FareSummary({required this.booking, required this.onChangePayment});

  final BookingProvider booking;
  final VoidCallback onChangePayment;

  @override
  Widget build(BuildContext context) {
    final fare = booking.fare;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onChangePayment,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Tr(
                  'Payment method',
                  style: TextStyle(color: Color(0xFF9AACC9), fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      booking.paymentLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 18),
          if (fare == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Tr(
                'Fare appears once the route is set',
                style: TextStyle(color: Color(0xFF9AACC9), fontSize: 12),
              ),
            )
          else ...[
            for (final line in fare.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const Divider(color: Colors.white24, height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Tr(
                  'Estimated total',
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
        ],
      ),
    );
  }
}

// Same fixed set as the Payment methods screen: cash and an e-wallet are
// always there, the card needs adding first. Watches AccountProvider (rather
// than taking a snapshot) so adding a card from here updates the list live
// instead of needing the sheet reopened.
class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet();

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

    final card = byType('card');

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Tr(
              'Select payment method',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          for (final type in ['cash', 'ewallet'])
            if (byType(type) case final method?) _tile(context, method),
          if (card != null)
            _tile(context, card)
          else
            ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.blue600),
              title: const Tr('Add card details', style: TextStyle(fontSize: 13)),
              onTap: () => showCardFormSheet(context, account),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, PaymentMethod method) {
    final IconData icon;
    final Color colour;
    switch (method.type) {
      case 'ewallet':
        icon = Icons.account_balance_wallet_outlined;
        colour = AppColors.blue600;
        break;
      case 'cash':
        icon = Icons.payments_outlined;
        colour = AppColors.ok;
        break;
      default:
        icon = Icons.credit_card;
        colour = AppColors.navy;
    }
    return ListTile(
      leading: Icon(icon, color: colour),
      title: Text(method.label, style: const TextStyle(fontSize: 13)),
      trailing: method.isDefault
          ? const Tr(
              'Default',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.blue600,
              ),
            )
          : null,
      onTap: () => Navigator.of(context).pop(method.label),
    );
  }
}
