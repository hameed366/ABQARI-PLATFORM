// Runs on a real Android device or emulator, with the Python engine packaged
// into the app (tools/package_python_engine.sh). Proves the full engine works
// inside the app itself, with no server.
import 'package:abqari_bridge/abqari_bridge.dart';
import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_math/l10n/math_strings.dart';
import 'package:abqari_math/main.dart';
import 'package:abqari_math/solver/solver_page.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = EmbeddedPythonEngine(startTimeout: const Duration(minutes: 4));

  testWidgets('the embedded Python engine answers on the device', (tester) async {
    final timings = <String, int>{};
    Future<SolveResult> timed(String text) async {
      final stopwatch = Stopwatch()..start();
      final result = (await tester.runAsync(() => engine.solve(text)))!;
      timings[text] = stopwatch.elapsedMilliseconds;
      return result;
    }

    final sine = await timed('sin(pi/6)');
    expect(sine.status, SolveStatus.solved);
    expect(sexpr(sine.answer!.expression!), '(div 1 2)');
    expect(sine.verification!.status, VerificationStatus.verified);

    final log = await timed('log(1000)');
    expect(sexpr(log.answer!.expression!), '3');

    final cubic = await timed('x^3 - 2 = 0');
    expect(cubic.status, SolveStatus.solved);
    expect(cubic.answer!.rootNodes, hasLength(1));
    expect(cubic.answer!.rootApproximations.single, closeTo(1.259921, 1e-6));

    final integral = await timed('integrate sin(x)^2');
    expect(integral.answer!.constantOfIntegration, isTrue);
    expect(integral.verification!.status, isNot(VerificationStatus.failed));

    final derivative = await timed('derivative of x^2 sin(x)');
    expect(derivative.verification!.status, VerificationStatus.verified);

    // ignore: avoid_print
    print('full engine timings (ms): $timings');
  });

  testWidgets('the solver screen hands off to the full engine and says so', (tester) async {
    final locale = LocaleController(store: InMemoryLocaleStore('ar'));
    await tester.pumpWidget(AbqariMathApp(
      localeController: locale,
      themeModeController: ThemeModeController(store: InMemoryThemeModeStore()),
      fullEngine: engine,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(SolverKeys.input), 'جا(π/٦)');
    await tester.tap(find.byKey(SolverKeys.solve));
    await tester.pump();
    for (var i = 0; i < 240 && find.byKey(SolverKeys.working).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text(const MathStringsAr().solvedByFullEngine), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is MathView && w.plainText == '١/٢'),
      findsOneWidget,
    );
  });
}
