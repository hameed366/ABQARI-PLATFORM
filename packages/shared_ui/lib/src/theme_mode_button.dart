import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'theme_mode_controller.dart';

/// App-bar action that cycles automatic → light → dark.
///
/// [tooltip] is supplied by the app so this package carries no text.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({
    super.key,
    required this.controller,
    required this.tooltip,
  });

  final ThemeModeController controller;
  final String tooltip;

  static IconData iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => IconButton(
        tooltip: tooltip,
        icon: Icon(iconFor(controller.mode)),
        onPressed: () => unawaited(controller.cycle()),
      ),
    );
  }
}
