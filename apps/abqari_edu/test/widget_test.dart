import 'package:abqari_edu/l10n/edu_strings.dart';
import 'package:abqari_edu/main.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = EduStringsAr();
const _en = EduStringsEn();

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(ListView)));

AbqariEduApp _app(LocaleController locale, [ThemeModeController? theme]) {
  return AbqariEduApp(
    localeController: locale,
    themeModeController:
        theme ?? ThemeModeController(store: InMemoryThemeModeStore()),
  );
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ListView))).brightness;

void main() {
  testWidgets('first launch is Arabic and right-to-left', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore());
    await tester.pumpWidget(_app(controller));
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
    await tester.pumpWidget(_app(controller));
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
    await tester.pumpWidget(_app(controller));
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
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, hasLength(3));
    for (final tile in tiles) {
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
    }
  });

  testWidgets('a saved dark choice opens dark with the brand surface', (tester) async {
    final theme = ThemeModeController(store: InMemoryThemeModeStore('dark'));
    await theme.load();
    await tester.pumpWidget(
      _app(LocaleController(store: InMemoryLocaleStore()), theme),
    );
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(ListView))).colorScheme.surface,
      AbqariColors.darkSurface,
    );
  });

  testWidgets('the appearance button switches to light then dark and saves', (tester) async {
    final store = InMemoryThemeModeStore();
    final theme = ThemeModeController(store: store);
    await tester.pumpWidget(
      _app(LocaleController(store: InMemoryLocaleStore()), theme),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ThemeModeButton));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light);
    expect(store.name, 'light');

    await tester.tap(find.byType(ThemeModeButton));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
    expect(store.name, 'dark');
  });

  testWidgets('appearance survives a language switch', (tester) async {
    final theme = ThemeModeController(store: InMemoryThemeModeStore('dark'));
    await theme.load();
    await tester.pumpWidget(
      _app(LocaleController(store: InMemoryLocaleStore()), theme),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.dark);
    expect(find.text(_en.headline), findsOneWidget);
  });

  testWidgets('home shows the logo and uses the edu lead colour', (tester) async {
    await tester.pumpWidget(
      _app(
        LocaleController(store: InMemoryLocaleStore()),
        ThemeModeController(
          store: InMemoryThemeModeStore(),
          initial: ThemeMode.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AbqariLogo), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ListView))).colorScheme.primary,
      AbqariTheme.light(AbqariProduct.edu).colorScheme.primary,
    );
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
