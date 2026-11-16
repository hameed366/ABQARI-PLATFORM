// The on-device engine against the same hand-worked reference set as the
// Python engine. For each problem it must either give the correct answer, or
// say plainly that the problem needs the full engine. It must never be wrong.
import 'dart:convert';
import 'dart:io';

import 'package:abqari_engine/abqari_engine.dart';
import 'package:test/test.dart';

final List<Map<String, dynamic>> problems = [
  for (final p in (jsonDecode(
    File('../../tests/math/reference_problems.json').readAsStringSync(),
  ) as Map<String, dynamic>)['problems'] as List)
    p as Map<String, dynamic>,
];

Node expected(String text) =>
    parse(normalize(text.replaceAll('**', '^')).text).lhs;

bool sameNumber(double? a, double? b) =>
    a != null && b != null && closeDoubles(a, b);

bool samePolynomial(Node a, Node b) {
  final names = {...variablesOf(a), ...variablesOf(b)};
  if (names.length > 1) return false;
  final x = names.isEmpty ? 'x' : names.single;
  final p = Poly.fromNode(a, x);
  final q = Poly.fromNode(b, x);
  return p != null && q != null && p == q;
}

/// Null when the device engine (correctly) declined the problem.
bool? grade(Map<String, dynamic> problem) {
  final result =
      solve(problem['input'] as String, task: problem['task'] as String?);
  if (result.verification?.status == VerificationStatus.failed) {
    fail('${problem['id']}: verification failed');
  }
  if (result.status == SolveStatus.unsupported &&
      result.errorCode == needsFullEngine) {
    return null;
  }
  final kind = problem['kind'] as String;
  final expect_ = problem['expect'];

  if (kind == 'status') {
    final e = expect_ as Map<String, dynamic>;
    return result.status.name == _statusName(e['status'] as String) &&
        result.errorCode == e['code'];
  }
  if (result.status != SolveStatus.solved) return false;
  final answer = result.answer!;
  final verifiedRequired = problem['verification'] == 'verified';
  if (verifiedRequired &&
      result.verification!.status != VerificationStatus.verified) {
    return false;
  }
  switch (kind) {
    case 'value':
      final want = expected(expect_ as String);
      final exactWant = exactRational(want);
      if (exactWant != null &&
          !(answer.exact!.isRational &&
              answer.exact!.rationalValue == exactWant)) {
        return false;
      }
      return sameNumber(numericDouble(want), answer.exact!.toDouble());
    case 'truth':
      return answer.truth == expect_;
    case 'solutions':
      final want = [
        for (final s in expect_ as List) numericDouble(expected(s as String))
      ];
      if (want.isEmpty) return answer.solutionSet == SolutionSet.none;
      if (answer.roots.length != want.length) return false;
      for (var i = 0; i < want.length; i++) {
        if (!sameNumber(want[i], answer.roots[i].toDouble())) return false;
      }
      return true;
    case 'all_real_numbers':
      return answer.solutionSet == SolutionSet.allReals;
    case 'equivalent':
      return samePolynomial(answer.expression!, expected(expect_ as String));
    case 'same_form':
      final same =
          samePolynomial(answer.expression!, expected(expect_ as String));
      if (problem['input'].toString().contains('factor') ||
          problem['input'].toString().startsWith('حلل')) {
        final e = answer.expression!;
        return same && (e is Mul || (e is Neg && e.operand is Mul));
      }
      return same;
    case 'antiderivative':
      final mine = Poly.fromNode(answer.expression!, 'x');
      final theirs = Poly.fromNode(expected(expect_ as String), 'x');
      return answer.constantOfIntegration &&
          mine != null &&
          theirs != null &&
          mine.derivative() == theirs.derivative();
  }
  fail('unknown kind $kind');
}

String _statusName(String python) => {
      'undefined': 'undefined',
      'unsupported': 'unsupported',
      'invalid_input': 'invalidInput'
    }[python]!;

void main() {
  for (final problem in problems) {
    test('${problem['id']}: ${problem['input']}', () {
      final verdict = grade(problem);
      expect(verdict, isNot(false),
          reason: 'wrong answer on the device engine');
    });
  }

  test('the device engine covers most of the reference set', () {
    final answered = problems.where((p) => grade(p) == true).length;
    final declined = problems.where((p) => grade(p) == null).length;
    // Recorded in docs/PHASE6_REPORT.md; raise the floor when coverage grows.
    expect(answered, greaterThanOrEqualTo(85),
        reason: '$answered answered, $declined declined');
    expect(answered + declined, problems.length);
  });
}
