import 'package:abqari_engine/abqari_engine.dart';
import 'package:test/test.dart';

List<String> rules(String text) => [for (final s in solve(text).steps) s.rule];

Node node(String text) => parse(normalize(text).text).lhs;

void main() {
  test('linear steps follow the balance method', () {
    final result = solve('2x + 3 = 7');
    expect(result.status, SolveStatus.solved);
    expect(rules('2x + 3 = 7'), ['subtract_both', 'divide_both', 'solutions']);
    final [subtract, divide, last] = result.steps;
    expect(sexpr(subtract.operand!), '3');
    expect(subtract.lines.single.toString(), '(mul 2 x) = 4');
    expect(sexpr(divide.operand!), '2');
    expect(last.lines.single.toString(), 'x = 2');
    expect(result.verification!.status, VerificationStatus.verified);
  });

  test('add or subtract is chosen by sign', () {
    expect(
        rules('3x - 5 = 2x + 7'), ['subtract_both', 'add_both', 'solutions']);
    expect(rules('7 = 2x + 3'),
        ['subtract_both', 'subtract_both', 'divide_both', 'solutions']);
    expect(rules('2(x - 3) = 4(x + 1)').first, 'expand_sides');
  });

  test('Arabic input solves for س', () {
    final result = solve('حل: ٣(س + ١) = ١٢');
    expect(result.variable, 'x');
    expect(result.answer!.roots.single.rationalValue.toString(), '3');
  });

  test('quadratic: discriminant, formula, factors', () {
    final result = solve('x^2 - 5x + 6 = 0');
    expect([
      for (final s in result.steps) s.rule
    ], [
      'standard_form',
      'discriminant',
      'quadratic_formula',
      'factorization',
      'solutions',
    ]);
    expect(result.steps[1].lines.single.parts.last.toString(), '1');
    expect(
        result.steps.last.lines.map((l) => l.toString()), ['x = 2', 'x = 3']);
  });

  test('irrational roots are exact and not given fake factors', () {
    final result = solve('x^2 - 2 = 0');
    expect(rules('x^2 - 2 = 0'), isNot(contains('factorization')));
    expect(result.answer!.rootNodes.map(sexpr), ['(neg (sqrt 2))', '(sqrt 2)']);
    expect(result.verification!.status, VerificationStatus.verified);
    final golden = solve('x^2 + x - 1 = 0').answer!.rootNodes.map(sexpr);
    expect(golden,
        ['(div (sub (neg 1) (sqrt 5)) 2)', '(div (add (neg 1) (sqrt 5)) 2)']);
  });

  test('no real solutions is proven, not assumed', () {
    final result = solve('x^2 + 1 = 0');
    expect(result.answer!.solutionSet, SolutionSet.none);
    expect(result.verification!.checks.map((c) => (c.name, c.passed)),
        [('root_count', true)]);
    expect(result.verification!.status, VerificationStatus.verified);
  });

  test('higher degree: rational roots plus Sturm completeness', () {
    final result = solve('(x-1)(x-2)(x-3)(x^2+1) = 0');
    expect(result.answer!.roots.map((r) => r.toString()), ['1', '2', '3']);
    expect(result.verification!.status, VerificationStatus.verified);
  });

  test('beyond the device engine it says so instead of guessing', () {
    for (final text in [
      'x^3 - 2 = 0',
      'sin(x) = 0',
      'sin(pi/6)',
      'log(100)',
      '1/x = 2'
    ]) {
      final result = solve(text);
      expect(result.status, SolveStatus.unsupported, reason: text);
      expect(result.errorCode, needsFullEngine, reason: text);
      expect(result.answer, isNull, reason: text);
    }
  });

  test('errors carry code, position and an understood form when available', () {
    final bad = solve('2 + \$ 3');
    expect(bad.status, SolveStatus.invalidInput);
    expect(bad.errorCode, 'unknown_symbol');
    expect(bad.errorPosition, 4);
    final undefined = solve('5/(3-3)');
    expect(undefined.status, SolveStatus.undefined);
    expect(undefined.understood, isNotNull);
    expect(solve('sqrt(-4)').errorCode, 'not_real');
    expect(solve('9^9^9').errorCode, 'number_too_large');
  });

  test('options are validated', () {
    expect(solve('x + 1', task: 'teleport').errorCode, 'unknown_task');
    expect(solve('x + 1', variable: 'e').errorCode, 'unknown_variable');
    expect(solve('x^2 = 4', task: 'differentiate').errorCode,
        'relation_needs_solve');
    expect(solve('solve x^2 + 1').errorCode, 'solve_needs_equation');
    expect(solve('(x+1)^2', task: 'expand').answer!.expression.toString(),
        '(add (add (pow x 2) (mul 2 x)) 1)');
  });

  group('verification catches wrong answers', () {
    test('a wrong expansion', () {
      expect(verifyEquivalence(node('(x+1)^2'), node('x^2 + 1'), 'x').status,
          VerificationStatus.failed);
      expect(
          verifyEquivalence(node('(x+1)^2'), node('x^2 + 2x + 1'), 'x').status,
          VerificationStatus.verified);
    });

    test('a missed root and a wrong root', () {
      final statement = parse(normalize('x^2 - 5x + 6 = 0').text);
      final f = Poly([Rational.fromInt(6), Rational.fromInt(-5), Rational.one]);
      final two = Surd.rational(Rational.fromInt(2));
      final four = Surd.rational(Rational.fromInt(4));
      final missed = verifyRoots(statement, 'x', f, [two]);
      expect(missed.status, VerificationStatus.failed);
      expect(missed.checks.where((c) => c.passed == false).map((c) => c.name),
          ['root_count']);
      final wrong = verifyRoots(statement, 'x', f, [two, four]);
      expect(wrong.checks.where((c) => c.passed == false).map((c) => c.name),
          containsAll(['substitution', 'floating_point_substitution']));
    });

    test('a wrong value, derivative and integral', () {
      expect(
          verifyEvaluation(
                  node('2 + 3 * 4'), Surd.rational(Rational.fromInt(15)))
              .status,
          VerificationStatus.failed);
      expect(verifyDerivative(node('x^3'), 'x', node('3x')).status,
          VerificationStatus.failed);
      expect(
        verifyIntegral(node('x^2'), 'x',
            Poly([Rational.zero, Rational.zero, Rational.one])).status,
        VerificationStatus.failed,
      );
    });

    test('nothing checked is never verified', () {
      final check = Verification();
      expect(check.status, VerificationStatus.partial);
      check.add('a', true);
      expect(check.status, VerificationStatus.verified);
      check.add('b', null);
      expect(check.status, VerificationStatus.partial);
      check.add('c', false);
      expect(check.status, VerificationStatus.failed);
    });
  });

  test('every message has Arabic and English, including every step rule', () {
    engineMessages.forEach((code, text) {
      expect(text.keys.toSet(), {'ar', 'en'}, reason: code);
      expect(text['ar']!.trim(), isNotEmpty, reason: code);
      expect(text['en']!.trim(), isNotEmpty, reason: code);
    });
    for (final text in [
      '2(x-3) = 4(x+1)',
      'x^2 - 5x + 6 = 0',
      'x + 1 = x + 2',
      'x^3 - x = 0',
      'x^2 + 2x + 1 = 0',
    ]) {
      for (final step in solve(text).steps) {
        expect(engineMessages, contains(step.messageCode), reason: step.rule);
      }
    }
  });
}
