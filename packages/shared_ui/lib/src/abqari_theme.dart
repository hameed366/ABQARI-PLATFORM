import 'package:material_ui/material_ui.dart';

import 'abqari_colors.dart';

/// Which app is being themed. Both share one identity; only the lead colour
/// differs so the two apps are told apart at a glance.
enum AbqariProduct { edu, math }

abstract final class AbqariTheme {
  static ThemeData light(AbqariProduct product) =>
      _build(product, Brightness.light);

  static ThemeData dark(AbqariProduct product) =>
      _build(product, Brightness.dark);

  static ThemeData _build(AbqariProduct product, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isEdu = product == AbqariProduct.edu;

    final Color primary;
    final Color secondary;
    if (isDark) {
      primary = isEdu ? AbqariColors.blueOnDark : AbqariColors.violetOnDark;
      secondary = isEdu ? AbqariColors.violetOnDark : AbqariColors.blueOnDark;
    } else {
      primary = isEdu ? AbqariColors.blue : AbqariColors.violet;
      secondary = isEdu ? AbqariColors.violet : AbqariColors.blue;
    }

    final scheme = ColorScheme.fromSeed(
      seedColor: isEdu ? AbqariColors.blue : AbqariColors.violet,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: isDark ? AbqariColors.navy : const Color(0xFFFFFFFF),
      secondary: secondary,
      onSecondary: isDark ? AbqariColors.navy : const Color(0xFFFFFFFF),
      surface: isDark ? AbqariColors.darkSurface : AbqariColors.lightSurface,
      onSurface: isDark ? const Color(0xFFE8ECF8) : AbqariColors.navy,
      surfaceContainerLow:
          isDark ? AbqariColors.darkSurfaceRaised : const Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
