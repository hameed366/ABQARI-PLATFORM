import 'dart:ui';

/// The languages every ABQARI app ships with.
abstract final class AbqariLocales {
  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');

  static const List<Locale> supported = [arabic, english];

  /// Used on first launch and whenever a saved value cannot be understood.
  static const Locale fallback = arabic;

  /// The supported locale for [languageCode], or null when it is not supported.
  static Locale? fromLanguageCode(String? languageCode) {
    for (final locale in supported) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }

  /// The language the user would switch to from [locale].
  static Locale other(Locale locale) =>
      locale.languageCode == arabic.languageCode ? english : arabic;
}
