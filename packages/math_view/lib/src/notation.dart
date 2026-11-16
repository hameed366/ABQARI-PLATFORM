import 'package:abqari_localization/abqari_localization.dart';
import 'package:material_ui/material_ui.dart';

/// How mathematics is written. Follows the interface language.
enum Notation {
  /// Right to left, Arabic-Indic digits, exponent at the top left of its base,
  /// mirrored radical, Arabic letters and function names.
  arabic,

  /// Left to right, Western digits, Latin letters and function names.
  latin;

  static Notation forLocale(Locale locale) =>
      locale.languageCode == 'ar' ? arabic : latin;

  TextDirection get direction =>
      this == arabic ? TextDirection.rtl : TextDirection.ltr;

  String number(String text) => this == arabic
      ? AbqariDigits.toArabicIndic(text).replaceAll('.', '٫')
      : AbqariDigits.toWestern(text);

  String variable(String name) =>
      this == arabic ? (_arabicLetters[name] ?? name) : name;

  String constant(String name) =>
      name == 'pi' ? 'π' : (this == arabic ? 'هـ' : 'e');

  String function(String name) =>
      this == arabic ? (_arabicFunctions[name] ?? name) : name;

  String symbol(String symbol) =>
      this == arabic ? (_arabicSymbols[symbol] ?? symbol) : symbol;

  static String relation(String relation) => _relations[relation] ?? relation;

  static const String minus = '−';
  static const String plus = '+';
  static const String times = '×';
  static const String plusMinus = '±';
}

const Map<String, String> _arabicLetters = {
  'x': 'س',
  'y': 'ص',
  'z': 'ع',
  'n': 'ن',
  'a': 'أ',
  'b': 'ب',
  'c': 'جـ',
  'm': 'م',
  'k': 'ك',
  't': 'ت',
  'r': 'ر',
};

const Map<String, String> _arabicFunctions = {
  'sin': 'جا',
  'cos': 'جتا',
  'tan': 'ظا',
  'log': 'لو',
  'ln': 'لط',
};

/// The constant of integration is written ث in Arabic.
const Map<String, String> _arabicSymbols = {'C': 'ث'};

const Map<String, String> _relations = {
  '=': '=',
  '<': '<',
  '>': '>',
  '<=': '≤',
  '>=': '≥',
  '!=': '≠',
};
