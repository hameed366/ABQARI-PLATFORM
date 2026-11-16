import 'dart:math' as math;

import 'errors.dart';
import 'nodes.dart';
import 'rational.dart';

const int maxExponent = 1000;
const int maxBits = 40000;
const int maxDigits = 40;

/// Exact value of [node] using integer arithmetic only, or null when the tree
/// is not plain rational arithmetic at [env].
///
/// Throws [MathDomainError] for division by zero and [MathInputError] when a
/// power would produce an unreasonably large number.
Rational? exactRational(Node node, {Map<String, Rational> env = const {}}) {
  switch (node) {
    case Num(:final text):
      if (text.replaceAll('.', '').length > maxDigits) {
        throw MathInputError('number_too_large',
            detail: '${text.substring(0, 12)}…');
      }
      return Rational.parse(text);
    case Var(:final name):
      return env[name];
    case Constant() || Sym() || PlusMinus():
      return null;
    case Neg(:final operand):
      final value = exactRational(operand, env: env);
      return value == null ? null : -value;
    case Call(:final function, :final argument):
      final value = exactRational(argument, env: env);
      if (value == null) return null;
      if (function == 'abs') return value.abs;
      if (function == 'sqrt') return exactSqrt(value);
      return null;
    case Add(:final left, :final right):
      return _binary(left, right, env, (a, b) => a + b);
    case Sub(:final left, :final right):
      return _binary(left, right, env, (a, b) => a - b);
    case Mul(:final left, :final right):
      return _binary(left, right, env, (a, b) => a * b);
    case Div(:final left, :final right):
      final a = exactRational(left, env: env);
      final b = exactRational(right, env: env);
      if (b != null && b.isZero) {
        throw const MathDomainError('division_by_zero');
      }
      return a == null || b == null ? null : a / b;
    case Pow(:final left, :final right):
      final base = exactRational(left, env: env);
      final exponent = exactRational(right, env: env);
      if (exponent != null &&
          exponent.abs.compareTo(Rational.fromInt(maxExponent)) > 0) {
        throw MathInputError('number_too_large', detail: 'exponent $exponent');
      }
      if (base == null || exponent == null || !exponent.isInteger) return null;
      final power = exponent.numerator.toInt();
      if (base.isZero && power < 0) {
        throw const MathDomainError('division_by_zero');
      }
      final bits = math.max(base.numerator.bitLength, base.denominator.bitLength);
      if (bits * power.abs() > maxBits) {
        throw const MathInputError('number_too_large', detail: 'power');
      }
      return base.pow(power);
  }
}

Rational? _binary(
  Node left,
  Node right,
  Map<String, Rational> env,
  Rational Function(Rational, Rational) combine,
) {
  final a = exactRational(left, env: env);
  final b = exactRational(right, env: env);
  return a == null || b == null ? null : combine(a, b);
}

/// Walks the whole tree so oversized constants and constant divisions by zero
/// are rejected before any solving starts.
void checkSize(Node node) {
  exactRational(node);
}

/// Rejects square roots of negative numbers and logarithms of non-positive
/// numbers wherever their argument is a known constant.
void checkRealDomain(Node node) {
  switch (node) {
    case Call(:final function, :final argument):
      checkRealDomain(argument);
      final value = exactRational(argument);
      if (value == null) return;
      if (function == 'sqrt' && value.isNegative) {
        throw const MathDomainError('not_real');
      }
      if ((function == 'ln' || function == 'log') && value.sign <= 0) {
        throw const MathDomainError('undefined');
      }
    case Num() || Var() || Constant() || Sym():
      return;
    case Neg(:final operand):
      checkRealDomain(operand);
    case Add(:final left, :final right) ||
          Sub(:final left, :final right) ||
          Mul(:final left, :final right) ||
          Div(:final left, :final right) ||
          Pow(:final left, :final right) ||
          PlusMinus(:final left, :final right):
      checkRealDomain(left);
      checkRealDomain(right);
  }
}

/// An exact number `a + b·√radicand`, where [radicand] is a square-free
/// positive integer. With radicand 1 the number is the rational `a + b`.
class Surd {
  const Surd(this.a, this.b, this.radicand);

  factory Surd.rational(Rational value) =>
      Surd(value, Rational.zero, BigInt.one);

  final Rational a;
  final Rational b;
  final BigInt radicand;

  bool get _isRationalField => radicand == BigInt.one;

  /// True when the value is rational.
  bool get isRational => _isRationalField || b.isZero;

  /// The rational value; only valid when [isRational].
  Rational get rationalValue => _isRationalField ? a + b : a;

  bool get isZero => isRational ? rationalValue.isZero : false;

  Rational get _r => Rational(radicand);

  Surd operator +(Surd other) => Surd(a + other.a, b + other.b, radicand);
  Surd operator -(Surd other) => Surd(a - other.a, b - other.b, radicand);
  Surd operator -() => Surd(-a, -b, radicand);
  Surd operator *(Surd other) => Surd(
        a * other.a + b * other.b * _r,
        a * other.b + b * other.a,
        radicand,
      );

  Surd operator /(Surd other) {
    final norm = other.a * other.a - other.b * other.b * _r;
    if (norm.isZero) throw const MathDomainError('division_by_zero');
    final product = this * Surd(other.a, -other.b, radicand);
    return Surd(product.a / norm, product.b / norm, radicand);
  }

  Surd pow(int exponent) {
    final one = Surd(Rational.one, Rational.zero, radicand);
    if (exponent < 0) return one / pow(-exponent);
    var result = one;
    var base = this;
    var remaining = exponent;
    while (remaining > 0) {
      if (remaining.isOdd) result = result * base;
      base = base * base;
      remaining >>= 1;
    }
    return result;
  }

  /// -1, 0 or 1, decided exactly.
  int get sign {
    if (isRational) return rationalValue.sign;
    final sa = a.sign;
    final sb = b.sign;
    if (sa == 0) return sb;
    if (sa == sb) return sa;
    // opposite signs: compare a² with b²·radicand
    final comparison = (a * a).compareTo(b * b * _r);
    if (comparison == 0) return 0;
    return comparison > 0 ? sa : sb;
  }

  double toDouble() =>
      a.toDouble() + b.toDouble() * math.sqrt(radicand.toDouble());

  /// Equal values. Irrational values are equal only within the same field,
  /// where the form a + b·√m is unique.
  @override
  bool operator ==(Object other) {
    if (other is! Surd) return false;
    if (isRational && other.isRational) {
      return rationalValue == other.rationalValue;
    }
    return radicand == other.radicand && a == other.a && b == other.b;
  }

  @override
  int get hashCode =>
      isRational ? rationalValue.hashCode : Object.hash(a, b, radicand);

  @override
  String toString() => isRational ? '$rationalValue' : '$a + $b·√$radicand';
}

/// Exact value of [node] with [variable] = [value], in the field of [value].
/// Null when the tree leaves that field (π, e, trigonometric functions…).
Surd? exactSurd(Node node, String variable, Surd value) {
  Surd lift(Rational rational) => Surd(rational, Rational.zero, value.radicand);
  switch (node) {
    case Num(:final text):
      return lift(Rational.parse(text));
    case Var(:final name):
      return name == variable ? value : null;
    case Constant() || Sym() || PlusMinus():
      return null;
    case Call():
      final constant = exactRational(node);
      return constant == null ? null : lift(constant);
    case Neg(:final operand):
      final inner = exactSurd(operand, variable, value);
      return inner == null ? null : -inner;
    case Add(:final left, :final right):
      final x = exactSurd(left, variable, value);
      final y = exactSurd(right, variable, value);
      return x == null || y == null ? null : x + y;
    case Sub(:final left, :final right):
      final x = exactSurd(left, variable, value);
      final y = exactSurd(right, variable, value);
      return x == null || y == null ? null : x - y;
    case Mul(:final left, :final right):
      final x = exactSurd(left, variable, value);
      final y = exactSurd(right, variable, value);
      return x == null || y == null ? null : x * y;
    case Div(:final left, :final right):
      final x = exactSurd(left, variable, value);
      final y = exactSurd(right, variable, value);
      return x == null || y == null ? null : x / y;
    case Pow(:final left, :final right):
      final base = exactSurd(left, variable, value);
      final exponent = exactRational(right);
      if (base == null || exponent == null || !exponent.isInteger) return null;
      final power = exponent.numerator.toInt();
      if (power.abs() > maxExponent) return null;
      return base.pow(power);
  }
}

/// Exact value of a constant expression whose square roots all live in one
/// field Q(√m). Null when it needs anything else (π, sin, two different roots…).
Surd? constantSurd(Node node) {
  final radicands = <BigInt>{};
  if (!_collectRadicands(node, radicands) || radicands.length > 1) return null;
  return _surdValue(node, radicands.isEmpty ? BigInt.one : radicands.single);
}

bool _collectRadicands(Node node, Set<BigInt> out) {
  switch (node) {
    case Call(function: 'sqrt', :final argument):
      final value = exactRational(argument);
      if (value == null) return false;
      if (value.isNegative) throw const MathDomainError('not_real');
      final (_, m) = sqrtParts(value);
      if (m != BigInt.one) out.add(m);
      return true;
    case Call(:final argument):
      return _collectRadicands(argument, out);
    case Num() || Var() || Constant() || Sym():
      return true;
    case Neg(:final operand):
      return _collectRadicands(operand, out);
    case Add(:final left, :final right) ||
          Sub(:final left, :final right) ||
          Mul(:final left, :final right) ||
          Div(:final left, :final right) ||
          Pow(:final left, :final right) ||
          PlusMinus(:final left, :final right):
      return _collectRadicands(left, out) && _collectRadicands(right, out);
  }
}

Surd? _surdValue(Node node, BigInt m) {
  Surd lift(Rational r) => Surd(r, Rational.zero, m);
  switch (node) {
    case Num(:final text):
      return lift(Rational.parse(text));
    case Var() || Constant() || Sym() || PlusMinus():
      return null;
    case Neg(:final operand):
      final inner = _surdValue(operand, m);
      return inner == null ? null : -inner;
    case Call(:final function, :final argument):
      if (function == 'sqrt') {
        final value = exactRational(argument);
        if (value == null) return null;
        final (s, root) = sqrtParts(value);
        return root == BigInt.one ? lift(s) : Surd(Rational.zero, s, m);
      }
      if (function == 'abs') {
        final inner = _surdValue(argument, m);
        if (inner == null) return null;
        return inner.sign < 0 ? -inner : inner;
      }
      return null;
    case Add(:final left, :final right):
      final x = _surdValue(left, m);
      final y = _surdValue(right, m);
      return x == null || y == null ? null : x + y;
    case Sub(:final left, :final right):
      final x = _surdValue(left, m);
      final y = _surdValue(right, m);
      return x == null || y == null ? null : x - y;
    case Mul(:final left, :final right):
      final x = _surdValue(left, m);
      final y = _surdValue(right, m);
      return x == null || y == null ? null : x * y;
    case Div(:final left, :final right):
      final x = _surdValue(left, m);
      final y = _surdValue(right, m);
      return x == null || y == null ? null : x / y;
    case Pow(:final left, :final right):
      final base = _surdValue(left, m);
      final exponent = exactRational(right);
      if (base == null || exponent == null || !exponent.isInteger) return null;
      final power = exponent.numerator.toInt();
      if (power.abs() > maxExponent) return null;
      if (base.isZero && power < 0) {
        throw const MathDomainError('division_by_zero');
      }
      return base.pow(power);
  }
}
