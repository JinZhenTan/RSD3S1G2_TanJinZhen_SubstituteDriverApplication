import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../providers/preferences_provider.dart';

// Module 4 - Language. A device-level preference held in PreferencesProvider
// and stored with shared_preferences (like the user_profile practical). Every
// UI string is written in English; picking another language machine-translates
// the interface (PreferencesProvider.t via TranslationService), cached so it
// only downloads once. Opening this screen pre-warms every language in the
// background, so tapping a row switches instantly.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // name -> native description
  static const Map<String, String> descriptions = {
    'English': 'Default',
    'Bahasa Malaysia': 'Bahasa Melayu',
    '中文': 'Mandarin',
    'தமிழ்': 'Tamil',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferencesProvider>().warmUpAllLanguages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesProvider>();
    final entries = PreferencesProvider.languages;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(eyebrow: 'PREFERENCES', title: 'Language'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Container(
                  decoration: AppStyles.card,
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.line),
                        ListTile(
                          title: Text(
                            entries[i],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(descriptions[entries[i]] ?? ''),
                          trailing: prefs.switchingTo == entries[i]
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : prefs.language == entries[i]
                                  ? const Icon(Icons.check,
                                      color: AppColors.blue600)
                                  : null,
                          onTap: prefs.switchingTo != null
                              ? null
                              : () => context
                                  .read<PreferencesProvider>()
                                  .setLanguage(entries[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Tr(
                    'The interface is machine-translated from English and cached '
                    'on this device. Some wording may read awkwardly.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
