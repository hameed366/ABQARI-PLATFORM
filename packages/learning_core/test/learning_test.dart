import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:test/test.dart';

Skill skill(String id) =>
    catalog.expand((p) => p.skills).firstWhere((s) => s.id == id);

final RegExp arabicLetter = RegExp('[؀-ۿ]');
final RegExp westernDigit = RegExp('[0-9]');

void main() {
  group('catalog', () {
    final skills = catalog.expand((p) => p.skills).toList();

    test(
        'ids are unique, well-formed, and prerequisites exist earlier in the path',
        () {
      final ids = skills.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in [...ids, ...catalog.map((p) => p.id)]) {
        expect(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id), isTrue,
            reason: id);
      }
      for (final path in catalog) {
        final seen = <String>{};
        for (final s in path.skills) {
          for (final p in s.prerequisites) {
            expect(seen, contains(p), reason: '${s.id} needs $p before it');
          }
          seen.add(s.id);
        }
      }
    });

    test('every text exists in both languages; Arabic uses Arabic-Indic digits',
        () {
      final texts = <Bilingual>[
        for (final path in catalog) ...[path.title, path.description],
        for (final s in skills) ...[
          s.title,
          s.instruction,
          if (s.answerHint != null) s.answerHint!,
          for (final block in s.lesson)
            if (block is Explanation) block.text,
        ],
      ];
      for (final t in texts) {
        expect(t.ar.trim(), isNotEmpty);
        expect(t.en.trim(), isNotEmpty);
        expect(arabicLetter.hasMatch(t.ar), isTrue, reason: t.ar);
        expect(westernDigit.hasMatch(t.ar), isFalse,
            reason: 'Western digit in: ${t.ar}');
        expect(arabicLetter.hasMatch(t.en), isFalse, reason: t.en);
      }
    });

    test('every worked example is solved and verified by the engine', () {
      for (final s in skills) {
        for (final block in s.lesson.whereType<WorkedExample>()) {
          final result = solve(block.problem);
          expect(result.status, SolveStatus.solved, reason: block.problem);
          expect(result.verification!.status, VerificationStatus.verified,
              reason: block.problem);
        }
      }
    });
  });

  group('practice', () {
    for (final s in catalog.expand((p) => p.skills)) {
      test('${s.id}: 200 questions, all verified, all answerable', () {
        final problems = <String>{};
        for (var seed = 0; seed < 200; seed++) {
          final q = makeQuestion(s, seed);
          expect(q.result.verification!.status, VerificationStatus.verified);
          problems.add(q.problem);
          // the engine's own answer, typed back, must be marked correct
          expect(mark(q, _typedAnswer(q)).verdict, Verdict.correct,
              reason: q.problem);
        }
        expect(problems.length, greaterThan(100), reason: 'enough variety');
      });
    }

    test('the same seed gives the same question', () {
      expect(makeQuestion(skill('two-step'), 7).problem,
          makeQuestion(skill('two-step'), 7).problem);
    });
  });

  group('marking', () {
    Question q(String id, String problem) {
      final s = skill(id);
      return Question(
          skill: s, seed: 0, problem: problem, result: solve(problem));
    }

    test('solutions: any order, Arabic digits, with or without "x ="', () {
      final question = q('solve-quadratic', 'x^2 - 5x + 6 = 0');
      for (final answer in [
        '2, 3',
        '3,2',
        '٣، ٢',
        'س = ٢ ، س = ٣',
        'x = 2 or x = 3',
        '2 أو 3',
        '2, 3, 3'
      ]) {
        expect(mark(question, answer).verdict, Verdict.correct, reason: answer);
      }
      expect(mark(question, '2').verdict, Verdict.incorrect);
      expect(mark(question, '2, 4').verdict, Verdict.incorrect);
      expect(mark(question, 'y = 2, y = 3').verdict, Verdict.unreadable);
    });

    test('values compare exactly', () {
      final question = q('add-fractions', '1/2 + 1/3');
      for (final answer in ['5/6', '10/12', '٥/٦']) {
        expect(mark(question, answer).verdict, Verdict.correct, reason: answer);
      }
      expect(mark(question, '0.83').verdict, Verdict.incorrect);
      expect(mark(q('add-fractions', '1/4 + 1/4'), '0.5').verdict,
          Verdict.correct);
    });

    test('unreadable and empty answers do not count against the learner', () {
      final question = q('two-step', '2x + 3 = 11');
      expect(mark(question, '').messageCode, 'answer_empty');
      expect(mark(question, 'four').verdict, Verdict.unreadable);
      expect(mark(question, 'hello').counts, isFalse);
      expect(mark(question, '1/0').verdict, Verdict.unreadable);
      expect(mark(question, '4').counts, isTrue);
    });

    test('expanded form is required where asked', () {
      final question = q('expand-binomials', 'expand (x + 2)(x + 3)');
      expect(mark(question, 'x^2 + 5x + 6').verdict, Verdict.correct);
      expect(mark(question, '6 + 5x + x^2').verdict, Verdict.correct);
      expect(mark(question, 'س^٢ + ٥س + ٦').verdict, Verdict.correct);
      final kept = mark(question, '(x + 2)(x + 3)');
      expect(kept.verdict, Verdict.wrongForm);
      expect(kept.messageCode, 'answer_not_expanded');
      expect(mark(question, 'x^2 + 6x + 6').verdict, Verdict.incorrect);
    });

    test('factored form is required where asked', () {
      final question = q('factor-trinomials', 'factor x^2 + 5x + 6');
      expect(mark(question, '(x + 2)(x + 3)').verdict, Verdict.correct);
      expect(mark(question, '(x+3)(x+2)').verdict, Verdict.correct);
      final square = q('factor-trinomials', 'factor x^2 + 6x + 9');
      expect(mark(square, '(x + 3)^2').verdict, Verdict.correct);
      expect(mark(question, 'x^2 + 5x + 6').messageCode, 'answer_not_factored');
      expect(mark(question, '(x + 1)(x + 6)').verdict, Verdict.incorrect);
    });
  });

  group('progress', () {
    test('mastery needs a full window with at least 80% correct', () {
      var p = const SkillProgress();
      expect(p.level, MasteryLevel.notStarted);
      for (final r in [true, true, false, true]) {
        p = p.record(r);
      }
      expect(p.level, isNot(MasteryLevel.mastered));
      p = p.record(true);
      expect(p.masteryPercent, 80);
      expect(p.level, MasteryLevel.mastered);
      p = p.record(false).record(false);
      expect(p.level, MasteryLevel.learning,
          reason: 'forgetting lowers mastery');
      expect(p.attempts, 7);
      expect(p.correct, 4);
    });

    test(
        'skills unlock when prerequisites are mastered; next skill is recommended',
        () {
      var learner = const LearnerProgress();
      expect(learner.isUnlocked(skill('one-step-add')), isTrue);
      expect(learner.isUnlocked(skill('one-step-multiply')), isFalse);
      expect(learner.recommendedNext(linearEquations)!.id, 'one-step-add');
      for (var i = 0; i < 5; i++) {
        learner = learner.record('one-step-add', true);
      }
      expect(learner.isUnlocked(skill('one-step-multiply')), isTrue);
      expect(learner.recommendedNext(linearEquations)!.id, 'one-step-multiply');
      expect(learner.pathPercent(linearEquations), 20);
    });

    test('progress survives encoding, and damaged data never crashes', () {
      final learner = const LearnerProgress()
          .record('two-step', true)
          .record('two-step', false);
      final again = LearnerProgress.decode(learner.encode());
      expect(again.of('two-step').attempts, 2);
      expect(again.of('two-step').recent, [true, false]);
      for (final junk in [
        null,
        '',
        'not json',
        '[]',
        '{"version":2}',
        '{"version":1,"skills":{"a":5}}'
      ]) {
        expect(LearnerProgress.decode(junk).of('a').attempts, 0);
      }
    });
  });
}

/// The engine's answer written the way a learner would type it.
String _typedAnswer(Question q) {
  final answer = q.result.answer!;
  switch (q.form) {
    case ExpectedForm.solutions:
      return answer.roots.map((r) => r.toString()).join(', ');
    case ExpectedForm.value:
      return answer.exact!.toString();
    case ExpectedForm.expanded:
    case ExpectedForm.factored:
      return _ascii(answer.expression!);
  }
}

String _ascii(Node n) => switch (n) {
      Num(:final text) => text,
      Var(:final name) => name,
      Constant(:final name) => name,
      Sym(:final symbol) => symbol,
      Neg(:final operand) => '-(${_ascii(operand)})',
      Add(:final left, :final right) =>
        '(${_ascii(left)}) + (${_ascii(right)})',
      Sub(:final left, :final right) =>
        '(${_ascii(left)}) - (${_ascii(right)})',
      Mul(:final left, :final right) => '(${_ascii(left)})*(${_ascii(right)})',
      Div(:final left, :final right) => '(${_ascii(left)})/(${_ascii(right)})',
      Pow(:final left, :final right) => '(${_ascii(left)})^(${_ascii(right)})',
      PlusMinus() => throw StateError('no ± in answers'),
      Call(:final function, :final argument) =>
        '$function(${_ascii(argument)})',
    };
