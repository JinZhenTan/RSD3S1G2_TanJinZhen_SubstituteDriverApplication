import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/account/providers/preferences_provider.dart';

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

extension TranslateContext on BuildContext {
  String tr(String text) =>
      Provider.of<PreferencesProvider>(this, listen: false).t(text);
}
