import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/account/providers/preferences_provider.dart';

// Drop-in replacement for Text() whose content is machine-translated into the
// language chosen on the Profile > Language screen. Write the English string
// here; PreferencesProvider.t() returns the translation (or English while it
// downloads). Because it only reads the provider inside build(), `const Tr(..)`
// still works everywhere `const Text(..)` did.
class Tr extends StatelessWidget {
  const Tr(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final translated = context.watch<PreferencesProvider>().t(text);
    return Text(
      translated,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

// For places that need the translated String itself rather than a widget -
// e.g. InputDecoration(labelText: context.tr('Password')), a validator message
// or a SnackBar. Uses listen:false so it is safe to call from callbacks; a
// screen that is open while the language changes will pick up the new text on
// its next rebuild. Use the Tr widget where you need an instant live update.
extension TranslateContext on BuildContext {
  String tr(String text) =>
      Provider.of<PreferencesProvider>(this, listen: false).t(text);
}
