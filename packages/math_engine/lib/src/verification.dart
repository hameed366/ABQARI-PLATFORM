import 'dart:math' as math;

import 'exact.dart';
import 'nodes.dart';
import 'numeric.dart';
import 'polynomial.dart';
import 'rational.dart';

/// verified — every applicable independent check passed.
/// partial  — nothing failed, but something could not be checked.
/// failed   — a check contradicted the answer. Do not present it as correct.
enum VerificationStatus { verified, partial, failed }

class Check {
  const Check(this.name, this.passed, [this.detail = '']);

  final String name;

  /// null = the check could not be carried out.
  final bool? passed;
  final String detail;

  @override
  String toString() => 'Check($name, $passed, $detail)';
}

class Verification {
  final List<Check> checks = [];

  void add(String name, bool? passed, [String detail = '']) =>
      checks.add(Check(name, passed, detail));

  void addAll(Verification other) => checks.addAll(other.checks);

  VerificationStatus get status {
    if (checks.any((check) => check.passed == false)) {
      return VerificationStatus.failed;
    }
    if (checks.isEmpty || checks.any((check) => check.passed == null)) {
      return VerificationStatus.partial;
    }
    return VerificationStatus.verified;
  }

  int get passedCount => checks.where((check) => check.passed == true).length;
}

const int minimumSamples = 3;

/// Distinct, reproducible rational sample points.
List<Rational> samplePoints(int count) => [
      for (var i = 0; i < count; i++)
        Rational(
          BigInt.from(i.isEven ? 2 * i + 3 : -(2 * i + 3)),
          BigInt.from(i + 5),
        ),
    ];

/// An upper bound on the degree in [variable] read directly from the tree,
/// without the polynomial code. Null when the tree is not polynomial-shaped.
int? degreeBound(Node node, String variable) {
  switch (node) {
    case Num() || Constant() || Sym():
      return 0;
    case Var(:final name):
      return name == variable ? 1 : 0;
    case Neg(:final operand):
      return degreeBound(operand, variable);
    case Call(:final argument):
      return degreeBound(argument, variable) == 0 ? 0 : null;
    case Add(:final left, :final right) ||
          Sub(:final left, :final right) ||
          PlusMinus(:final left, :final right):
      final a = degreeBound(left, variable);
      final b = degreeBound(right, variable);
      return a == null || b == null ? null : math.max(a, b);
    case Mul(:final left, :final right):
      final a = degreeBound(left, variable);
      final b = degreeBound(right, variable);
      return a == null || b == null ? null : a + b;
    case Div(:final left, :final right):
      return degreeBound(right, variable) == 0
          ? degreeBound(left, variable)
          : null;
    case Pow(:final left, :final right):
      final base = degreeBound(left, variable);
      if (base == null || degreeBound(right, variable) != 0) return null;
      if (base == 0) return 0;
      final exponent = exactRational(right);
      if (exponent == null || !exponent.isInteger || exponent.isNegative) {
        return null;
      }
      return base * exponent.numerator.toInt();
  }
}

/// Two one-variable expressions denote the same function.
///
/// Exact check: both are evaluated with fractions at more points than their
/// degree bound, so agreement is a proof, not a sample. Floating-point check:
/// an unrelated evaluator at the same points.
Verification verifyEquivalence(Node typed, Node result, String variable) {
  final check = Verification();
  final a = degreeBound(typed, variable);
  final b = degreeBound(result, variable);
  final bound = a == null || b == null ? null : math.max(a, b);
  final points = samplePoints(math.max(8, (bound ?? 0) + 1));

  var agree = 0, disagree = 0, unusable = 0;
  for (final point in points) {
    final x = exactRational(typed, env: {variable: point});
    final y = exactRational(result, env: {variable: point});
    if (x == null || y == null) {
      unusable++;
    } else if (x == y) {
      agree++;
    } else {
      disagree++;
    }
  }
  if (disagree > 0) {
    check.add('exact_sampling', false, '$disagree point(s) disagree');
  } else if (bound != null && unusable == 0) {
    check.add('exact_sampling', true,
        'identical at ${points.length} points; degree at most $bound');
  } else {
    check.add('exact_sampling', null, '$agree exact point(s) only');
  }
  check.add('floating_point_sampling', _floatingAgreement(typed, result, variable));
  return check;
}

bool? _floatingAgreement(Node typed, Node result, String variable) {
  var agree = 0;
  for (final point in samplePoints(8)) {
    final x = numericDouble(typed, env: {variable: point.toDouble()});
    final y = numericDouble(result, env: {variable: point.toDouble()});
    if (x == null || y == null) continue;
    if (!closeDoubles(x, y)) return false;
    agree++;
  }
  return agree >= minimumSamples ? true : null;
}

/// A constant expression has the exact [value].
Verification verifyEvaluation(Node typed, Surd value) {
  final check = Verification();
  final independent = numericDouble(typed);
  check.add(
    'floating_point',
    independent != null && closeDoubles(independent, value.toDouble()),
  );
  final fraction = exactRational(typed);
  if (fraction != null) {
    check.add(
      'exact_fraction_arithmetic',
      value.isRational && value.rationalValue == fraction,
    );
  }
  return check;
}

/// A relation between constants is [truth].
Verification verifyStatement(Statement statement, bool truth) {
  final check = Verification();
  final left = numericDouble(statement.lhs);
  final right = numericDouble(statement.rhs!);
  if (left == null || right == null) {
    check.add('floating_point', false, 'a side is not a finite real');
  } else if (closeDoubles(left, right)) {
    final equalityTruths = {'=', '<=', '>='};
    check.add('floating_point',
        truth == equalityTruths.contains(statement.relation), 'sides agree');
  } else {
    final difference = left - right;
    final expected = switch (statement.relation) {
      '=' => false,
      '!=' => true,
      '<' => difference < 0,
      '>' => difference > 0,
      '<=' => difference < 0,
      _ => difference > 0,
    };
    check.add('floating_point', expected == truth, 'sides differ');
  }
  return check;
}

/// [roots] is exactly the set of real solutions of `lhs = rhs`, where
/// [difference] is lhs − rhs as a polynomial.
Verification verifyRoots(
  Statement statement,
  String variable,
  Poly difference,
  List<Surd> roots,
) {
  final check = Verification();
  for (final root in roots) {
    final left = exactSurd(statement.lhs, variable, root);
    final right = exactSurd(statement.rhs!, variable, root);
    check.add(
      'substitution',
      left == null || right == null ? null : (left - right).isZero,
      '$variable = $root',
    );
    final x = numericDouble(statement.lhs, env: {variable: root.toDouble()});
    final y = numericDouble(statement.rhs!, env: {variable: root.toDouble()});
    check.add(
      'floating_point_substitution',
      x != null && y != null && closeDoubles(x, y),
      '$variable = $root',
    );
  }
  final expected = distinctRealRootCount(difference);
  check.add('root_count', expected == roots.length,
      "Sturm's theorem: $expected distinct real root(s)");
  return check;
}

/// Both sides agree everywhere (the equation is an identity).
Verification verifyIdentity(Statement statement, String variable) =>
    _verifyConstantDifference(statement, variable, Rational.zero);

/// lhs − rhs is the non-zero constant [constant] (no solution).
Verification verifyNoSolution(
  Statement statement,
  String variable,
  Rational constant,
) =>
    _verifyConstantDifference(statement, variable, constant);

Verification _verifyConstantDifference(
  Statement statement,
  String variable,
  Rational constant,
) {
  final check = Verification();
  final a = degreeBound(statement.lhs, variable);
  final b = degreeBound(statement.rhs!, variable);
  if (a == null || b == null) {
    check.add('exact_sampling', null, 'not polynomial-shaped');
    return check;
  }
  final points = samplePoints(math.max(minimumSamples, math.max(a, b) + 1));
  for (final point in points) {
    final x = exactRational(statement.lhs, env: {variable: point});
    final y = exactRational(statement.rhs!, env: {variable: point});
    if (x == null || y == null) {
      check.add('exact_sampling', null, 'a side could not be evaluated');
      return check;
    }
    if (x - y != constant) {
      check.add('exact_sampling', false, 'difference is not constant');
      return check;
    }
  }
  check.add('exact_sampling', true, 'lhs − rhs = $constant at ${points.length} points');
  return check;
}

/// [result] is the derivative of [typed] in [variable].
Verification verifyDerivative(Node typed, String variable, Node result) {
  final check = Verification();
  var agree = 0, disagree = 0;
  for (final point in samplePoints(8)) {
    final x = point.toDouble();
    final h = 1e-5 * (1 + x.abs());
    final above = numericDouble(typed, env: {variable: x + h});
    final below = numericDouble(typed, env: {variable: x - h});
    final claimed = numericDouble(result, env: {variable: x});
    if (above == null || below == null || claimed == null) continue;
    final slope = (above - below) / (2 * h);
    if ((slope - claimed).abs() <= 1e-5 * (1 + slope.abs() + claimed.abs())) {
      agree++;
    } else {
      disagree++;
    }
  }
  check.add(
    'numerical_differentiation',
    disagree > 0 ? false : (agree >= minimumSamples ? true : null),
    '$agree agree, $disagree disagree',
  );
  return check;
}

/// [antiderivative] is an antiderivative of [typed] in [variable].
Verification verifyIntegral(Node typed, String variable, Poly antiderivative) {
  final check = Verification();
  final integrand = Poly.fromNode(typed, variable);
  check.add(
    'differentiate_back',
    integrand == null ? null : antiderivative.derivative() == integrand,
  );
  var agree = 0, disagree = 0;
  for (final point in samplePoints(8)) {
    final start = point.toDouble();
    const width = 0.25;
    final area = _simpson(typed, variable, start, start + width);
    if (area == null) continue;
    final claimed = antiderivative.evaluate(point + Rational(BigInt.one, BigInt.from(4))).toDouble() -
        antiderivative.evaluate(point).toDouble();
    if ((area - claimed).abs() <= 1e-8 * (1 + area.abs() + claimed.abs())) {
      agree++;
    } else {
      disagree++;
    }
  }
  check.add(
    'numerical_quadrature',
    disagree > 0 ? false : (agree >= minimumSamples ? true : null),
    '$agree agree, $disagree disagree',
  );
  return check;
}

double? _simpson(Node node, String variable, double a, double b) {
  const n = 64;
  final h = (b - a) / n;
  var sum = 0.0;
  for (var i = 0; i <= n; i++) {
    final value = numericDouble(node, env: {variable: a + i * h});
    if (value == null) return null;
    final weight = i == 0 || i == n ? 1 : (i.isOdd ? 4 : 2);
    sum += weight * value;
  }
  return sum * h / 3;
}
