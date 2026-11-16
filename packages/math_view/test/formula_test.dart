import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Statement statement(String text) => parse(normalize(text).text);
Node expression(String text) => statement(text).lhs;

Future<void> show(WidgetTester tester, Widget view) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: view))),
    );

final RegExp westernDigit = RegExp('[0-9]');

void main() {
  group('plain text', () {
    const cases = <String, (String, String)>{
      '2x + 3 = 7': ('٢س + ٣ = ٧', '2x + 3 = 7'),
      'x^2 - 5x + 6 = 0': ('س^٢ − ٥س + ٦ = ٠', 'x^2 − 5x + 6 = 0'),
      'sin(x) + cos(x)': ('جا(س) + جتا(س)', 'sin(x) + cos(x)'),
      '2 pi r': ('٢πر', '2πr'),
      '3.5 * 2': ('٣٫٥ × ٢', '3.5 × 2'),
      'x <= 3': ('س ≤ ٣', 'x ≤ 3'),
      'sqrt(x + 1)': ('√(س + ١)', '√(x + 1)'),
      'a - (b - c)': ('أ − (ب − جـ)', 'a − (b − c)'),
      '-x^2': ('−س^٢', '−x^2'),
      '(x+1)(x-1)': ('(س + ١)(س − ١)', '(x + 1)(x − 1)'),
      'e^x': ('هـ^س', 'e^x'),
      'log(100)': ('لو(١٠٠)', 'log(100)'),
    };
    cases.forEach((input, expected) {
      test(input, () {
        expect(
            statementPlainText(statement(input), Notation.arabic), expected.$1);
        expect(
            statementPlainText(statement(input), Notation.latin), expected.$2);
      });
    });

    test('the constant of integration is ث in Arabic', () {
      expect(mathPlainText(const Add(Var('x'), Sym('C')), Notation.arabic),
          'س + ث');
      expect(mathPlainText(const Add(Var('x'), Sym('C')), Notation.latin),
          'x + C');
    });

    test('approximations use the notation digits', () {
      expect(approximateText(1.41421356237, Notation.arabic), '١٫٤١٤٢١٣٥٦٢');
      expect(approximateText(-0.5, Notation.latin), '−0.5');
      expect(approximateText(2.0, Notation.latin), '2');
      expect(approximateText(1e20, Notation.latin), isNull);
    });

    test('notation follows the interface language', () {
      expect(Notation.forLocale(const Locale('ar')), Notation.arabic);
      expect(Notation.forLocale(const Locale('en')), Notation.latin);
    });
  });

  group('drawing', () {
    testWidgets(
        'Arabic notation uses only Arabic-Indic digits and Arabic letters',
        (tester) async {
      await show(
          tester,
          MathView.statement(statement('12x^2 + 3.5 = 70'),
              notation: Notation.arabic));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data!)
          .toList();
      expect(texts, contains('س'));
      expect(texts, contains('١٢'));
      expect(texts, contains('٣٫٥'));
      expect(texts.where(westernDigit.hasMatch), isEmpty);
      expect(texts, isNot(contains('x')));
    });

    testWidgets('Latin notation uses Western digits and Latin letters',
        (tester) async {
      await show(
          tester,
          MathView.statement(statement('12x^2 + 3.5 = 70'),
              notation: Notation.latin));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data!)
          .toList();
      expect(texts, containsAll(['x', '12', '3.5', '70']));
    });

    testWidgets('Arabic: the exponent sits at the top left of its base',
        (tester) async {
      await show(tester,
          MathView.expression(expression('x^2'), notation: Notation.arabic));
      final base = tester.getRect(find.byKey(MathViewKeys.base));
      final exponent = tester.getRect(find.byKey(MathViewKeys.exponent));
      expect(exponent.center.dx, lessThan(base.center.dx));
      expect(exponent.center.dy, lessThan(base.center.dy));
    });

    testWidgets('Latin: the exponent sits at the top right of its base',
        (tester) async {
      await show(tester,
          MathView.expression(expression('x^2'), notation: Notation.latin));
      final base = tester.getRect(find.byKey(MathViewKeys.base));
      final exponent = tester.getRect(find.byKey(MathViewKeys.exponent));
      expect(exponent.center.dx, greaterThan(base.center.dx));
      expect(exponent.center.dy, lessThan(base.center.dy));
    });

    testWidgets('Arabic reads right to left: the first term is rightmost',
        (tester) async {
      await show(tester,
          MathView.expression(expression('2 + 3'), notation: Notation.arabic));
      expect(tester.getCenter(find.text('٢')).dx,
          greaterThan(tester.getCenter(find.text('٣')).dx));
    });

    testWidgets('Latin reads left to right', (tester) async {
      await show(tester,
          MathView.expression(expression('2 + 3'), notation: Notation.latin));
      expect(tester.getCenter(find.text('2')).dx,
          lessThan(tester.getCenter(find.text('3')).dx));
    });

    testWidgets('the radical is mirrored in Arabic only', (tester) async {
      bool flipped() {
        Widget? parent;
        tester
            .element(find.byKey(MathViewKeys.radical))
            .visitAncestorElements((ancestor) {
          parent = ancestor.widget;
          return false;
        });
        return parent is Transform;
      }

      await show(
          tester,
          MathView.expression(expression('sqrt(2)'),
              notation: Notation.arabic));
      expect(flipped(), isTrue);
      final arabicRoot = tester.getRect(find.byKey(MathViewKeys.radical));
      expect(arabicRoot.center.dx,
          greaterThan(tester.getRect(find.text('٢')).center.dx));

      await show(tester,
          MathView.expression(expression('sqrt(2)'), notation: Notation.latin));
      expect(flipped(), isFalse);
      final latinRoot = tester.getRect(find.byKey(MathViewKeys.radical));
      expect(latinRoot.center.dx,
          lessThan(tester.getRect(find.text('2')).center.dx));
    });

    testWidgets('a fraction puts the numerator above the denominator',
        (tester) async {
      await show(tester,
          MathView.expression(expression('1/2'), notation: Notation.arabic));
      final top = tester.getRect(find.byKey(MathViewKeys.numerator));
      final bottom = tester.getRect(find.byKey(MathViewKeys.denominator));
      expect(top.bottom, lessThanOrEqualTo(bottom.top));
    });

    testWidgets('function names and constants follow the notation',
        (tester) async {
      await show(
          tester,
          MathView.expression(expression('sin(x) + tan(pi)'),
              notation: Notation.arabic));
      expect(find.text('جا'), findsOneWidget);
      expect(find.text('ظا'), findsOneWidget);
      expect(find.text('π'), findsOneWidget);
    });

    testWidgets('a chain draws every part with equals signs', (tester) async {
      final view = MathView.chain(
        const EquationChain([Var('x'), Num('2')]),
        notation: Notation.arabic,
      );
      await show(tester, view);
      expect(view.plainText, 'س = ٢');
      expect(find.text('='), findsOneWidget);
    });

    testWidgets('every engine answer can be drawn without layout errors',
        (tester) async {
      for (final input in [
        'x^2 + x - 1 = 0',
        '2(x - 3) = 4(x + 1)',
        '(x-1)(x-2)(x-3) = 0',
        'x^2 + 2x + 1 = 0',
      ]) {
        final result = solve(input);
        for (final step in result.steps) {
          for (final line in step.lines) {
            for (final notation in Notation.values) {
              await show(
                  tester,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathView.chain(line, notation: notation),
                  ));
              expect(tester.takeException(), isNull,
                  reason: '$input / $notation');
            }
          }
        }
      }
    });
  });
}
