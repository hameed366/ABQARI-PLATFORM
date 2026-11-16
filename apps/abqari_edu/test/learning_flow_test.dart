import 'package:abqari_edu/l10n/edu_strings.dart';
import 'package:abqari_edu/learning/path_page.dart';
import 'package:abqari_edu/learning/practice_page.dart';
import 'package:abqari_edu/learning/progress_controller.dart';
import 'package:abqari_edu/learning/skill_page.dart';
import 'package:abqari_edu/main.dart';
import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = EduStringsAr();
final Skill firstSkill = linearEquations.skills.first;

Finder mathShowing(String plain) =>
    find.byWidgetPredicate((w) => w is MathView && w.plainText == plain);

/// The app opened straight on a practice page with a fixed first question.
Future<ProgressController> openPractice(
  WidgetTester tester, {
  Skill? skill,
  int seed = 0,
  InMemoryProgressStore? store,
}) async {
  final progress = ProgressController(store: store ?? InMemoryProgressStore());
  await progress.load();
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AbqariLocales.supported,
    localizationsDelegates: [
      EduStrings.delegate,
      CommonStrings.delegate,
      ...GlobalMaterialLocalizations.delegates
    ],
    home: PracticePage(
        skill: skill ?? firstSkill, progress: progress, firstSeed: seed),
  ));
  await tester.pumpAndSettle();
  return progress;
}

Future<void> answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(PracticeKeys.answer), text);
  await tester.tap(find.byKey(PracticeKeys.check));
  await tester.pumpAndSettle();
}

String rightAnswer(Skill skill, int seed) => makeQuestion(skill, seed)
    .result
    .answer!
    .roots
    .map((r) => r.toString())
    .join(', ');

void main() {
  testWidgets(
      'home → path → skill: lesson, worked example with steps, practice',
      (tester) async {
    final progress = ProgressController(store: InMemoryProgressStore());
    await tester.pumpWidget(AbqariEduApp(
      localeController: LocaleController(store: InMemoryLocaleStore()),
      themeModeController: ThemeModeController(store: InMemoryThemeModeStore()),
      progressController: progress,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(linearEquations.title.ar));
    await tester.pumpAndSettle();
    expect(find.byType(PathPage), findsOneWidget);
    expect(find.text('${_ar.recommended} · ${_ar.levelNotStarted}'),
        findsOneWidget);
    for (final skill in linearEquations.skills) {
      expect(find.text(skill.title.ar), findsOneWidget);
    }
    // only the first skill is open
    expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('skill-one-step-add')))
            .enabled,
        isTrue);
    expect(
        tester
            .widget<ListTile>(
                find.byKey(const ValueKey('skill-one-step-multiply')))
            .enabled,
        isFalse);

    await tester.tap(find.text(firstSkill.title.ar));
    await tester.pumpAndSettle();
    expect(find.byType(SkillPage), findsOneWidget);
    expect(find.text((firstSkill.lesson.first as Explanation).text.ar),
        findsOneWidget);
    expect(mathShowing('س + ٥ = ١٢'), findsOneWidget, reason: 'worked example');
    expect(mathShowing('س = ٧'), findsWidgets, reason: 'worked example answer');
    expect(
        find.text(engineMessage('step_subtract_both', 'ar')), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(SkillKeys.practice), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(SkillKeys.practice));
    await tester.pumpAndSettle();
    expect(find.byType(PracticePage), findsOneWidget);
  });

  testWidgets('a correct answer is confirmed, counted and saved',
      (tester) async {
    final store = InMemoryProgressStore();
    final progress = await openPractice(tester, store: store);

    await answer(tester, rightAnswer(firstSkill, 0));

    expect(find.text(_ar.correct), findsOneWidget);
    expect(progress.progress.of(firstSkill.id).attempts, 1);
    expect(progress.progress.of(firstSkill.id).correct, 1);
    expect(LearnerProgress.decode(store.data).of(firstSkill.id).correct, 1);
    expect(find.byKey(PracticeKeys.next), findsOneWidget);
  });

  testWidgets(
      'a wrong answer shows the correct answer and, on request, the steps',
      (tester) async {
    final progress = await openPractice(tester);
    final question = makeQuestion(firstSkill, 0);
    final wrong =
        (question.result.answer!.roots.single.rationalValue + Rational.one)
            .toString();

    await answer(tester, wrong);

    expect(find.text(_ar.incorrect), findsOneWidget);
    expect(find.text(_ar.correctAnswerIs), findsOneWidget);
    expect(progress.progress.of(firstSkill.id).attempts, 1);
    expect(progress.progress.of(firstSkill.id).correct, 0);

    await tester.tap(find.byKey(PracticeKeys.solution));
    await tester.pumpAndSettle();
    expect(find.byType(MathView), findsWidgets);
    expect(find.byKey(PracticeKeys.solution), findsNothing);
  });

  testWidgets('an unreadable answer explains itself and is not counted',
      (tester) async {
    final progress = await openPractice(tester);

    await answer(tester, 'hello');

    expect(find.text(markingMessages['answer_unreadable']!.ar), findsOneWidget);
    expect(progress.progress.of(firstSkill.id).attempts, 0);
    expect(find.byKey(PracticeKeys.check), findsOneWidget,
        reason: 'can try again');
  });

  testWidgets('"another question" brings a new problem', (tester) async {
    await openPractice(tester);
    final before = makeQuestion(firstSkill, 0).problem;
    await answer(tester, rightAnswer(firstSkill, 0));
    await tester.tap(find.byKey(PracticeKeys.next));
    await tester.pumpAndSettle();

    final after = makeQuestion(firstSkill, 1);
    expect(after.problem, isNot(before));
    expect(
      mathShowing(
          statementPlainText(after.result.understood!, Notation.arabic)),
      findsOneWidget,
    );
  });

  testWidgets('mastering a skill unlocks the next one on the path',
      (tester) async {
    final progress = ProgressController(store: InMemoryProgressStore());
    for (var i = 0; i < 5; i++) {
      await progress.record(firstSkill.id, true);
    }
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AbqariLocales.supported,
      localizationsDelegates: [
        EduStrings.delegate,
        CommonStrings.delegate,
        ...GlobalMaterialLocalizations.delegates
      ],
      home: PathPage(path: linearEquations, progress: progress),
    ));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ListTile>(
                find.byKey(const ValueKey('skill-one-step-multiply')))
            .enabled,
        isTrue);
    expect(find.text(_ar.levelMastered), findsOneWidget);
    expect(find.text(_ar.pathProgress(20)), findsOneWidget);
  });

  testWidgets('saved progress is there after a relaunch', (tester) async {
    final store = InMemoryProgressStore();
    final first = ProgressController(store: store);
    await first.record('fractions-unused', true);
    await first.record(firstSkill.id, true);

    final relaunched = ProgressController(store: store);
    await relaunched.load();
    expect(relaunched.progress.of(firstSkill.id).correct, 1);
  });
}
