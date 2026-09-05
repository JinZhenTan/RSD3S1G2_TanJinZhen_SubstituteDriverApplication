import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/profile.dart';
import '../../../models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../../driver/providers/driver_provider.dart';
import '../../driver/screens/earnings_screen.dart';
import '../../driver/services/earnings_exporter.dart';
import '../../service_staff/providers/service_staff_provider.dart';
import '../../service_staff/screens/staff_activity_screen.dart';
import '../../service_staff/screens/staff_earnings_screen.dart';
import '../../vehicle_services/providers/car_service_provider.dart';
import '../providers/account_provider.dart';
import '../providers/preferences_provider.dart';
import 'help_support_screen.dart';
import 'language_screen.dart';
import 'notification_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'receipts_screen.dart';
import 'safety_preferences_screen.dart';
import 'vehicle_details_screen.dart';

// Module 4 - Profile tab. Navy hero with the profile row, then grouped menu
// links to every account sub-page, and Sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<PreferencesProvider>();
    final profile = account.profile;
    final name = profile?.name ?? auth.session?.user.email ?? 'Guest';
    final role = profile?.role ?? UserRole.user;

    // The hero line under the name is just the account role - the rating
    // (drivers/passengers) has its own place (Earnings / trip history), not
    // here.
    String roleSubtitle;
    switch (role) {
      case UserRole.driver:
        roleSubtitle = 'Substitute driver';
        break;
      case UserRole.serviceStaff:
        roleSubtitle = 'Car service partner';
        break;
      case UserRole.user:
        roleSubtitle = 'Passenger';
        break;
    }

    return Container(
      color: AppColors.page,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppStyles.navyGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: profile == null
                    ? null
                    : () => _showEditSheet(context, profile),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.blue500, AppColors.blue700],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (profile?.initial ?? name[0]).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Tr(
                          roleSubtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.heroAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.white70),
                ],
                ),
              ),
            ),
          ),
          _GroupLabel('Account'),
          _MenuGroup(children: [
            // Drivers and service partners get paid, not billed - "Payment
            // methods" becomes a salary + per-job/per-trip earnings
            // breakdown instead (the owner pays for the service, not them).
            if (role == UserRole.driver)
              _MenuItem(
                icon: Icons.payments_outlined,
                label: 'Earnings',
                onTap: () => _push(context, const EarningsScreen()),
              )
            else if (role == UserRole.serviceStaff)
              _MenuItem(
                icon: Icons.payments_outlined,
                label: 'Earnings',
                onTap: () => _push(context, const StaffEarningsScreen()),
              )
            else
              _MenuItem(
                icon: Icons.credit_card,
                label: 'Payment methods',
                onTap: () => _push(context, const PaymentMethodsScreen()),
              ),
            if (role == UserRole.driver)
              _MenuItem(
                icon: Icons.file_download_outlined,
                label: 'Export earning log',
                onTap: () => _exportDriverEarnings(context),
              )
            else if (role == UserRole.serviceStaff)
              // The service partner's own work history (jobs they've
              // accepted) - not receipts, they don't get paid through here.
              _MenuItem(
                icon: Icons.history,
                label: 'Activity',
                onTap: () => _push(context, const StaffActivityScreen()),
              )
            else
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Activity & receipts',
                onTap: () => _push(context, const ReceiptsScreen()),
              ),
            // A substitute driver drives the passenger's car and has no
            // vehicle of their own, so this is a passenger-only page.
            if (role == UserRole.user)
              _MenuItem(
                icon: Icons.directions_car_outlined,
                label: 'My vehicle details',
                onTap: () => _push(context, const VehicleDetailsScreen()),
              ),
          ]),
          _GroupLabel('Preferences'),
          _MenuGroup(children: [
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notification settings',
              onTap: () => _push(context, const NotificationSettingsScreen()),
            ),
            _MenuItem(
              icon: Icons.language,
              label: 'Language',
              trailingText: prefs.language,
              onTap: () => _push(context, const LanguageScreen()),
            ),
            _MenuItem(
              icon: Icons.warning_amber_outlined,
              label: 'Safety alert preferences',
              onTap: () => _push(context, const SafetyPreferencesScreen()),
            ),
          ]),
          // No Help & Support group for the service partner role.
          if (role != UserRole.serviceStaff) ...[
            _GroupLabel('Support'),
            _MenuGroup(children: [
              _MenuItem(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () => _push(context, const HelpSupportScreen()),
              ),
            ]),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: OutlinedButton(
              onPressed: () {
                // Clear every role's provider state before signing out so the
                // next account that logs in on this device starts clean.
                context.read<AccountProvider>().clear();
                context.read<BookingProvider>().clear();
                context.read<CarServiceProvider>().clear();
                context.read<DriverProvider>().clear();
                context.read<ServiceStaffProvider>().clear();
                context.read<AuthProvider>().signOut();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.line, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Tr('Sign out'),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // One-tap CSV/PDF export of the driver's current-month completed trips,
  // without a detour through the Earnings screen - see EarningsExporter.
  Future<void> _exportDriverEarnings(BuildContext context) async {
    final driver = context.read<DriverProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await driver.loadEarningsForMonth(DateTime.now());
    final trips = driver.completedMonthlyTrips;
    if (trips.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No completed bookings to export yet.')),
      );
      return;
    }
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Tr(
                'Export earning log',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Tr('Export as CSV'),
              onTap: () => Navigator.pop(sheetContext, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Tr('Export as PDF'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'csv') {
      await EarningsExporter.exportCsv(trips, driver.earningsMonth);
    } else if (choice == 'pdf') {
      await EarningsExporter.exportPdf(trips, driver.earningsMonth);
    }
  }

  // Edit the name / phone on the profiles row.
  Future<void> _showEditSheet(BuildContext context, Profile profile) async {
    final nameController = TextEditingController(text: profile.name);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final account = context.read<AccountProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tr(
              'Edit profile',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: sheetContext.tr('Name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: sheetContext.tr('Phone')),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await account.updateProfile(
                    name: nameController.text,
                    phone: phoneController.text,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Tr('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Tr(text.toUpperCase(),
          style: AppStyles.mono.copyWith(fontSize: 9.5)),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: AppStyles.card,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // Optional value shown before the chevron (e.g. the current language).
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: AppColors.blue600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tr(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (trailingText != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFB3BAC2)),
          ],
        ),
      ),
    );
  }
}
