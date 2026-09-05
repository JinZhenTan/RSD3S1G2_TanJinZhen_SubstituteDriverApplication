import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';

// Module 4 - Help & support. A static FAQ list plus a contact button.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Each map has a 'q' (question) and an 'a' (answer).
  static const List<Map<String, String>> faqs = [
    {
      'q': 'How is the fare calculated?',
      'a': 'A flagfall covers the first 10 km, then each additional km is '
          'charged at a fixed per-km rate shown before you confirm. A small '
          'wet-weather buffer is added when your route passes an active '
          'weather alert.',
    },
    {
      'q': 'Can the driver take my car for servicing too?',
      'a': 'Yes - use Car Service from the home screen to schedule a company '
          'driver to pick up, service, and return your car. You pay after it '
          'is returned.',
    },
    {
      'q': 'What happens if the driver deviates from the route?',
      'a': 'Live sharing lets a trusted contact follow the route in real '
          'time, and you can message the driver directly from the booking '
          'screen.',
    },
  ];

  static const String supportEmail = 'support@ganti.my';
  static const String supportPhone = '+60 3-2100 8899';

  Future<void> _showContactSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tr(
                  'Contact support',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tr(
                  'Our team replies within 24 hours.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text(supportEmail),
              subtitle: const Tr('Tap to copy'),
              onTap: () => _copy(sheetContext, supportEmail),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text(supportPhone),
              subtitle: const Tr('Tap to copy'),
              onTap: () => _copy(sheetContext, supportPhone),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext sheetContext, String value) {
    final messenger = ScaffoldMessenger.of(sheetContext);
    Clipboard.setData(ClipboardData(text: value));
    Navigator.pop(sheetContext);
    messenger.showSnackBar(
      SnackBar(content: Text('Copied $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'SUPPORT', title: 'Help & support'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Tr(
                  'FREQUENTLY ASKED',
                  style: AppStyles.mono.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 8),
                for (final faq in faqs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: AppStyles.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tr(
                          faq['q']!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Tr(
                          faq['a']!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Contact support',
                  onPressed: () => _showContactSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
