import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(ThemeModeController controller, Widget body) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      theme: AbqariTheme.light(AbqariProduct.edu),
      darkTheme: AbqariTheme.dark(AbqariProduct.edu),
      themeMode: controller.mode,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ThemeModeButton(controller: controller, tooltip: 'appearance')
          ],
        ),
        body: body,
      ),
    ),
  );
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold))).brightness;

void main() {
  testWidgets('appearance button cycles light → dark and updates its icon',
      (tester) async {
    final controller = ThemeModeController(store: InMemoryThemeModeStore());
    await tester.pumpWidget(_app(controller, const SizedBox()));
    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    expect(find.byTooltip('appearance'), findsOneWidget);

    await tester.tap(find.byType(ThemeModeButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
    expect(_brightness(tester), Brightness.light);

    await tester.tap(find.byType(ThemeModeButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    expect(_brightness(tester), Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.surface,
      AbqariColors.darkSurface,
    );
  });

  testWidgets('feature card shows its text and is not a control',
      (tester) async {
    final controller = ThemeModeController(store: InMemoryThemeModeStore());
    await tester.pumpWidget(
      _app(
        controller,
        const FeatureCard(
            icon: Icons.functions, title: 'Title', subtitle: 'Subtitle'),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNull);
    expect(tile.trailing, isNull);
  });

  testWidgets(
      'a feature card with an action is tappable and its arrow follows direction',
      (tester) async {
    var taps = 0;
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: FeatureCard(
                icon: Icons.functions,
                title: 'Title',
                subtitle: 'Subtitle',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      final arrow = tester.widget<Icon>(find.byIcon(Icons.arrow_forward));
      expect(arrow.icon!.matchTextDirection, isTrue);
      final tile = tester.getRect(find.byType(ListTile));
      final arrowRect = tester.getRect(find.byIcon(Icons.arrow_forward));
      if (direction == TextDirection.rtl) {
        expect(arrowRect.center.dx, lessThan(tile.center.dx));
      } else {
        expect(arrowRect.center.dx, greaterThan(tile.center.dx));
      }
      await tester.tap(find.byType(ListTile));
    }
    expect(taps, 2);
  });

  testWidgets('logo paints at small and large sizes and is labelled',
      (tester) async {
    final controller = ThemeModeController(store: InMemoryThemeModeStore());
    for (final size in [16.0, 56.0, 300.0]) {
      await tester
          .pumpWidget(_app(controller, Center(child: AbqariLogo(size: size))));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AbqariLogo)), Size(size, size));
    }
    expect(find.bySemanticsLabel('ABQARI'), findsOneWidget);
  });

  testWidgets('logo is not mirrored in right-to-left layouts', (tester) async {
    const painter = AbqariLogoPainter();
    expect(painter.shouldRepaint(const AbqariLogoPainter()), isFalse);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: AbqariLogo()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
