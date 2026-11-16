import 'dart:ui';

/// Converts between Western digits (0–9) and the Arabic-Indic digits (٠–٩)
/// used in Arabic text — the ones commonly called "Hindi" numerals in Arabic.
///
/// Only digits change. Operators, letters, and separators are left untouched,
/// so this is safe to apply to any text containing numbers.
abstract final class AbqariDigits {
  static const int _westernZero = 0x30;
  static const int _arabicIndicZero = 0x0660;

  static String toArabicIndic(String text) =>
      _shift(text, from: _westernZero, to: _arabicIndicZero);

  static String toWestern(String text) =>
      _shift(text, from: _arabicIndicZero, to: _westernZero);

  /// Arabic-Indic digits for Arabic, Western digits for every other language.
  static String forLocale(String text, Locale locale) =>
      locale.languageCode == 'ar' ? toArabicIndic(text) : toWestern(text);

  static String _shift(String text, {required int from, required int to}) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final offset = rune - from;
      buffer.writeCharCode(offset >= 0 && offset <= 9 ? to + offset : rune);
    }
    return buffer.toString();
  }
}
