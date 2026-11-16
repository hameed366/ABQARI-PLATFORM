import 'dart:async';

import 'package:abqari_bridge/abqari_bridge.dart';
import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_math/l10n/math_strings.dart';
import 'package:abqari_math/main.dart';
import 'package:abqari_math/solver/solver_page.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = MathStringsAr();

/// Opens the app straight on the solver, in [language].
Future<LocaleController> openSolver(
  WidgetTester tester, {
  String language = 'ar',
  FullEngine? fullEngine,
}) async {
  final locale = LocaleController(store: InMemoryLocaleStore(language));
  await locale.load();
  await tester.pumpWidget(AbqariMathApp(
    localeController: locale,
    themeModeController: ThemeModeController(store: InMemoryThemeModeStore()),
    fullEngine: fullEngine,
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ListTile).first);
  await tester.pumpAndSettle();
  expect(find.byType(SolverPage), findsOneWidget);
  return locale;
}

Future<void> solveTyped(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(SolverKeys.input), text);
  await tester.tap(find.byKey(SolverKeys.solve));
  await tester.pumpAndSettle();
}

Finder mathShowing(String plain) => find.byWidgetPredicate(
    (widget) => widget is MathView && widget.plainText == plain);

void main() {
  testWidgets(
      'solves a linear equation on the device and shows it in Arabic notation',
      (tester) async {
    await openSolver(tester);
    await solveTyped(tester, '٢س + ٣ = ٧');

    expect(mathShowing('٢س + ٣ = ٧'), findsOneWidget,
        reason: 'understood form');
    expect(mathShowing('س = ٢'), findsWidgets, reason: 'answer and final step');
    expect(find.text(engineMessage('verification_verified', 'ar')),
        findsOneWidget);
    expect(find.text(_ar.stepsTitle), findsOneWidget);
    expect(
        find.text(engineMessage('step_subtract_both', 'ar')), findsOneWidget);
    expect(find.text(engineMessage('step_divide_both', 'ar')), findsOneWidget);
  });

  testWidgets('switching to English redraws the same result in Latin notation',
      (tester) async {
    await openSolver(tester);
    await solveTyped(tester, '2x + 3 = 7');
    expect(mathShowing('س = ٢'), findsWidgets);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(mathShowing('x = 2'), findsWidgets);
    expect(mathShowing('س = ٢'), findsNothing);
    expect(find.text(engineMessage('verification_verified', 'en')),
        findsOneWidget);
  });

  testWidgets('quadratic: exact irrational roots with a decimal approximation',
      (tester) async {
    await openSolver(tester, language: 'en');
    await solveTyped(tester, 'x^2 - 2 = 0');

    expect(mathShowing('x = −√2'), findsWidgets);
    expect(mathShowing('x = √2'), findsWidgets);
    expect(find.text('≈ 1.414213562'), findsOneWidget);
    expect(find.text(engineMessage('step_discriminant', 'en')), findsOneWidget);
  });

  testWidgets('an example chip fills the input and solves it', (tester) async {
    await openSolver(tester);
    await tester.tap(find.text(_ar.examples[1]));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(SolverKeys.input));
    expect(field.controller!.text, _ar.examples[1]);
    expect(mathShowing('س = ٢'), findsWidgets);
    expect(mathShowing('س = ٣'), findsWidgets);
  });

  testWidgets('unreadable input explains why, in the interface language',
      (tester) async {
    await openSolver(tester);
    await solveTyped(tester, 'hello');

    expect(find.text(engineMessage('unknown_word', 'ar')), findsOneWidget);
    expect(
        find.text(engineMessage('verification_verified', 'ar')), findsNothing);
  });

  testWidgets('problems beyond the device engine are declined, never guessed',
      (tester) async {
    await openSolver(tester);
    await solveTyped(tester, 'جا(س) = ٠');

    expect(find.text(engineMessage('needs_full_engine', 'ar')), findsOneWidget);
    expect(find.text(_ar.answerTitle), findsNothing);
  });

  testWidgets('division by zero is reported as undefined', (tester) async {
    await openSolver(tester, language: 'en');
    await solveTyped(tester, '5/(3-3)');

    expect(find.text(engineMessage('division_by_zero', 'en')), findsOneWidget);
    expect(mathShowing('5/(3 − 3)'), findsOneWidget);
  });

  group('the full engine', () {
    testWidgets('is never asked what the device core can answer', (tester) async {
      final engine = FakeFullEngine((_) async => throw StateError('must not be called'));
      await openSolver(tester, fullEngine: engine);
      await solveTyped(tester, '٢س + ٣ = ٧');

      expect(engine.asked, isEmpty);
      expect(mathShowing('س = ٢'), findsWidgets);
      expect(find.text(_ar.solvedByFullEngine), findsNothing);
    });

    testWidgets('answers what the core declines, and says so', (tester) async {
      final reply = Completer<SolveResult>();
      final engine = FakeFullEngine((_) => reply.future);
      await openSolver(tester, fullEngine: engine);

      await tester.enterText(find.byKey(SolverKeys.input), 'جا(س) = ٠');
      await tester.tap(find.byKey(SolverKeys.solve));
      await tester.pump();
      expect(find.byKey(SolverKeys.working), findsOneWidget);
      expect(find.text(_ar.fullEngineWorking), findsOneWidget);
      expect(engine.asked, ['جا(س) = ٠']);

      reply.complete(solveResultFromJson(sineReply));
      await tester.pumpAndSettle();

      expect(find.byKey(SolverKeys.working), findsNothing);
      expect(mathShowing('س = ٠'), findsOneWidget);
      expect(mathShowing('س = π'), findsOneWidget);
      expect(find.text(_ar.solvedByFullEngine), findsOneWidget);
      expect(find.text(engineMessage('verification_partial', 'ar')), findsOneWidget);
    });

    testWidgets('when it cannot run, the core\'s honest answer stays', (tester) async {
      final engine = FakeFullEngine((_) async => throw const FullEngineUnavailable('start_timeout'));
      await openSolver(tester, fullEngine: engine);
      await solveTyped(tester, 'جا(س) = ٠');

      expect(find.text(_ar.fullEngineUnavailable), findsOneWidget);
      expect(find.text(engineMessage('needs_full_engine', 'ar')), findsOneWidget);
      expect(find.text(_ar.solvedByFullEngine), findsNothing);
    });

    testWidgets('a late answer to an old problem is ignored', (tester) async {
      final slow = Completer<SolveResult>();
      final engine = FakeFullEngine((_) => slow.future);
      await openSolver(tester, fullEngine: engine);

      await tester.enterText(find.byKey(SolverKeys.input), 'جا(س) = ٠');
      await tester.tap(find.byKey(SolverKeys.solve));
      await tester.pump();
      await solveTyped(tester, '٢س + ٣ = ٧');
      slow.complete(solveResultFromJson(sineReply));
      await tester.pumpAndSettle();

      expect(mathShowing('س = ٢'), findsWidgets);
      expect(mathShowing('س = π'), findsNothing);
    });
  });
}

class FakeFullEngine implements FullEngine {
  FakeFullEngine(this.respond);

  final Future<SolveResult> Function(String text) respond;
  final List<String> asked = [];

  @override
  Future<SolveResult> solve(String text) {
    asked.add(text);
    return respond(text);
  }
}

/// Shaped like the Python engine's reply for sin(x) = 0 on a bounded range.
const Map<String, dynamic> sineReply = {
  'input': {'raw': 'جا(س) = ٠', 'normalized': 'sin(x) = 0'},
  'status': 'solved',
  'task': 'solve_equation',
  'variable': 'x',
  'answer': {
    'kind': 'finite',
    'solutions': [
      {'plain': '0', 'tree': ['num', '0']},
      {'plain': 'pi', 'approx': '3.14159265359', 'tree': ['const', 'pi']},
    ],
  },
  'notes': [],
  'verification': {
    'status': 'partial',
    'checks': [
      {'name': 'substitution', 'passed': true, 'detail': 'x = 0'},
      {'name': 'root_count', 'passed': null, 'detail': 'not provable'},
    ],
  },
};
