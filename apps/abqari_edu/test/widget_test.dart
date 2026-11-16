import 'package:abqari_edu/l10n/edu_strings.dart';
import 'package:abqari_edu/learning/progress_controller.dart';
import 'package:abqari_edu/main.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = EduStringsAr();
const _en = EduStringsEn();

AbqariEduApp _app(
  LocaleController locale, {
  ThemeModeController? theme,
  ProgressController? progress,
}) {
  return AbqariEduApp(
    localeController: locale,
    themeModeController: theme ?? ThemeModeController(store: InMemoryThemeModeStore()),
    progressController: progress ?? ProgressController(store: InMemoryProgressStore()),
  );
}

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(ListView).first));

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ListView).first)).brightness;

void main() {
  testWidgets('first launch is Arabic and right-to-left', (tester) async {
    await tester.pumpWidget(_app(LocaleController(store: InMemoryLocaleStore())));
    await tester.pumpAndSettle();

    for (final text in _ar.all) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_direction(tester), TextDirection.rtl);
  });

  testWidgets('home lists every learning path, each one opens', (tester) async {
    await tester.pumpWidget(_app(LocaleController(store: InMemoryLocaleStore())));
    await tester.pumpAndSettle();

    for (final path in catalog) {
      expect(find.text(path.title.ar), findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.descendant(of: find.byKey(ValueKey('path-${path.id}')), matching: find.byType(ListTile)),
      );
      expect(tile.onTap, isNotNull);
    }
  });

  testWidgets('a saved English choice opens in English, left-to-right', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore('en'));
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    for (final text in _en.all) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text(catalog.first.title.en), findsOneWidget);
    expect(_direction(tester), TextDirection.ltr);
  });

  testWidgets('the language button switches every string at once and saves', (tester) async {
    final store = InMemoryLocaleStore();
    await tester.pumpWidget(_app(LocaleController(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text(_en.headline), findsOneWidget);
    expect(find.text(_ar.headline), findsNothing);
    expect(_direction(tester), TextDirection.ltr);
    expect(store.languageCode, 'en');

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text(_ar.headline), findsOneWidget);
    expect(_direction(tester), TextDirection.rtl);
  });

  testWidgets('a saved dark choice opens dark with the brand surface', (tester) async {
    final theme = ThemeModeController(store: InMemoryThemeModeStore('dark'));
    await theme.load();
    await tester.pumpWidget(_app(LocaleController(store: InMemoryLocaleStore()), theme: theme));
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(ListView).first)).colorScheme.surface,
      AbqariColors.darkSurface,
    );
  });

  testWidgets('home shows the logo and uses the edu lead colour', (tester) async {
    await tester.pumpWidget(_app(
      LocaleController(store: InMemoryLocaleStore()),
      theme: ThemeModeController(store: InMemoryThemeModeStore(), initial: ThemeMode.light),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AbqariLogo), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ListView).first)).colorScheme.primary,
      AbqariTheme.light(AbqariProduct.edu).colorScheme.primary,
    );
  });

  test('both languages are complete and in the right script', () {
    final arabicLetters = RegExp(r'[؀-ۿ]');
    final westernDigits = RegExp('[0-9]');
    expect(_ar.everything.length, _en.everything.length);
    for (final text in _ar.everything) {
      expect(text.trim(), isNotEmpty);
      expect(arabicLetters.hasMatch(text), isTrue, reason: text);
      expect(westernDigits.hasMatch(text), isFalse, reason: 'Arabic uses ٠–٩: $text');
    }
    for (final text in _en.everything) {
      expect(text.trim(), isNotEmpty);
      expect(arabicLetters.hasMatch(text), isFalse, reason: text);
    }
  });
}
