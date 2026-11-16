import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'common_strings.dart';
import 'locale_controller.dart';

/// App-bar action that switches between Arabic and English immediately.
class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final strings = CommonStrings.of(context);
    return Tooltip(
      message: strings.switchLanguageTooltip,
      child: TextButton(
        onPressed: () => unawaited(controller.toggle()),
        child: Text(strings.otherLanguageName),
      ),
    );
  }
}
