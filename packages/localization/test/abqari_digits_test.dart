import 'dart:ui';

import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts every Western digit to Arabic-Indic', () {
    expect(AbqariDigits.toArabicIndic('0123456789'), '٠١٢٣٤٥٦٧٨٩');
  });

  test('converts every Arabic-Indic digit to Western', () {
    expect(AbqariDigits.toWestern('٠١٢٣٤٥٦٧٨٩'), '0123456789');
  });

  test('leaves operators, letters and spacing untouched', () {
    expect(AbqariDigits.toArabicIndic('2x + 35 = 7.5'), '٢x + ٣٥ = ٧.٥');
    expect(AbqariDigits.toArabicIndic('س = 12'), 'س = ١٢');
    expect(AbqariDigits.toArabicIndic('π'), 'π');
    expect(AbqariDigits.toArabicIndic(''), '');
  });

  test('round-trips mixed text', () {
    const original = 'Area = 3 × 14 cm², ratio 1:2';
    expect(AbqariDigits.toWestern(AbqariDigits.toArabicIndic(original)), original);
  });

  test('is idempotent', () {
    const once = '٤٢';
    expect(AbqariDigits.toArabicIndic(once), once);
    expect(AbqariDigits.toWestern('42'), '42');
  });

  test('forLocale picks the digits of the language', () {
    expect(AbqariDigits.forLocale('٧ + 8', const Locale('ar')), '٧ + ٨');
    expect(AbqariDigits.forLocale('٧ + 8', const Locale('en')), '7 + 8');
  });

  test('does not touch other numeral systems or superscripts', () {
    expect(AbqariDigits.toArabicIndic('x² ۵'), 'x² ۵');
  });
}
