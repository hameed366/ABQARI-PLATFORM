import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(LocaleController controller) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: AbqariLocales.supported,
      localizationsDelegates: [
        CommonStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(
        appBar: AppBar(actions: [LanguageSwitchButton(controller: controller)]),
        body: const TextField(),
      ),
    ),
  );
}

void main() {
  testWidgets('offers the other language, in that language', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore());
    await tester.pumpWidget(_host(controller));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsNothing);
  });

  testWidgets('one tap switches language and direction, and saves',
      (tester) async {
    final store = InMemoryLocaleStore();
    final controller = LocaleController(store: store);
    await tester.pumpWidget(_host(controller));
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.locale, const Locale('en'));
    expect(store.languageCode, 'en');
    expect(find.text('العربية'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr);
  });

  testWidgets('switching language keeps what the user typed', (tester) async {
    final controller = LocaleController(store: InMemoryLocaleStore());
    await tester.pumpWidget(_host(controller));
    await tester.enterText(find.byType(TextField), '2x + 3 = 7');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('2x + 3 = 7'), findsOneWidget);
  });
}
