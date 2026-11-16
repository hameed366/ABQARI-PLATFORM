import 'package:abqari_math/l10n/math_strings.dart';
import 'package:abqari_math/main.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = MathStringsAr();
const _en = MathStringsEn();

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(ListView)));

void main() {
  testWidgets('first launch is Arabic and right-to-left', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore());
    await tester.pumpWidget(AbqariMathApp(localeController: controller));
    await tester.pumpAndSettle();

    for (final text in _ar.all) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_direction(tester), TextDirection.rtl);
  });

  testWidgets('a saved English choice opens in English, left-to-right',
      (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore('en'));
    await controller.load();
    await tester.pumpWidget(AbqariMathApp(localeController: controller));
    await tester.pumpAndSettle();

    for (final text in _en.all) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_direction(tester), TextDirection.ltr);
  });

  testWidgets('the language button switches every string at once and saves',
      (tester) async {
    final store = InMemoryLocaleStore();
    final controller = LocaleController(store: store);
    await tester.pumpWidget(AbqariMathApp(localeController: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    for (final text in _en.all) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text(_ar.headline), findsNothing);
    expect(_direction(tester), TextDirection.ltr);
    expect(store.languageCode, 'en');

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text(_ar.headline), findsOneWidget);
    expect(_direction(tester), TextDirection.rtl);
    expect(store.languageCode, 'ar');
  });

  testWidgets('feature cards do not pretend to be buttons', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore());
    await tester.pumpWidget(AbqariMathApp(localeController: controller));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, hasLength(3));
    for (final tile in tiles) {
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
    }
  });

  test('both languages are complete and in the right script', () {
    final arabicLetters = RegExp(r'[؀-ۿ]');
    expect(_ar.all.length, _en.all.length);
    for (final text in _ar.all) {
      expect(text.trim(), isNotEmpty);
      expect(arabicLetters.hasMatch(text), isTrue, reason: text);
    }
    for (final text in _en.all) {
      expect(text.trim(), isNotEmpty);
      expect(arabicLetters.hasMatch(text), isFalse, reason: text);
    }
  });
}
