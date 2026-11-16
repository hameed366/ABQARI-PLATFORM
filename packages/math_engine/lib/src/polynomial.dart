import 'errors.dart';
import 'exact.dart';
import 'nodes.dart';
import 'rational.dart';

const int maxDegree = 200;

/// A polynomial in one variable with exact rational coefficients.
class Poly {
  Poly(List<Rational> coefficients) : coefficients = _trim(coefficients);

  Poly.constant(Rational value) : this([value]);

  /// The polynomial `x`.
  Poly.variable() : this([Rational.zero, Rational.one]);

  /// Index = power. No trailing zeros; the zero polynomial is the empty list.
  final List<Rational> coefficients;

  static List<Rational> _trim(List<Rational> values) {
    var length = values.length;
    while (length > 0 && values[length - 1].isZero) {
      length--;
    }
    return List.unmodifiable(values.sublist(0, length));
  }

  /// -1 for the zero polynomial.
  int get degree => coefficients.length - 1;
  bool get isZero => coefficients.isEmpty;

  Rational coefficient(int power) =>
      power < coefficients.length ? coefficients[power] : Rational.zero;

  Poly operator +(Poly other) {
    final length = coefficients.length > other.coefficients.length
        ? coefficients.length
        : other.coefficients.length;
    return Poly([
      for (var i = 0; i < length; i++) coefficient(i) + other.coefficient(i),
    ]);
  }

  Poly operator -() => Poly([for (final c in coefficients) -c]);

  Poly operator -(Poly other) => this + (-other);

  Poly operator *(Poly other) {
    if (isZero || other.isZero) return Poly(const []);
    if (degree + other.degree > maxDegree) {
      throw const MathInputError('number_too_large', detail: 'degree');
    }
    final result = List<Rational>.filled(
      coefficients.length + other.coefficients.length - 1,
      Rational.zero,
    );
    for (var i = 0; i < coefficients.length; i++) {
      for (var j = 0; j < other.coefficients.length; j++) {
        result[i + j] = result[i + j] + coefficients[i] * other.coefficients[j];
      }
    }
    return Poly(result);
  }

  Poly scale(Rational factor) => Poly([for (final c in coefficients) c * factor]);

  /// Exact value at [x] by Horner's rule.
  Rational evaluate(Rational x) {
    var result = Rational.zero;
    for (var i = coefficients.length - 1; i >= 0; i--) {
      result = result * x + coefficients[i];
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Poly || other.coefficients.length != coefficients.length) {
      return false;
    }
    for (var i = 0; i < coefficients.length; i++) {
      if (coefficients[i] != other.coefficients[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(coefficients);

  @override
  String toString() => 'Poly($coefficients)';

  /// [node] as a polynomial in [variable], or null when it is not one
  /// (another variable, a function, π, a variable in a denominator or exponent).
  static Poly? fromNode(Node node, String variable) {
    switch (node) {
      case Num(:final text):
        return Poly.constant(Rational.parse(text));
      case Var(:final name):
        return name == variable ? Poly.variable() : null;
      case Constant() || Sym() || PlusMinus():
        return null;
      case Call():
        final value = exactRational(node);
        return value == null ? null : Poly.constant(value);
      case Neg(:final operand):
        final inner = fromNode(operand, variable);
        return inner == null ? null : -inner;
      case Add(:final left, :final right):
        final a = fromNode(left, variable);
        final b = fromNode(right, variable);
        return a == null || b == null ? null : a + b;
      case Sub(:final left, :final right):
        final a = fromNode(left, variable);
        final b = fromNode(right, variable);
        return a == null || b == null ? null : a - b;
      case Mul(:final left, :final right):
        final a = fromNode(left, variable);
        final b = fromNode(right, variable);
        return a == null || b == null ? null : a * b;
      case Div(:final left, :final right):
        final a = fromNode(left, variable);
        final b = fromNode(right, variable);
        if (a == null || b == null) return null;
        if (b.isZero) throw const MathDomainError('division_by_zero');
        if (b.degree > 0) return null;
        return a.scale(b.coefficient(0).inverse);
      case Pow(:final left, :final right):
        final base = fromNode(left, variable);
        final exponent = exactRational(right);
        if (base == null || exponent == null) return null;
        if (!exponent.isInteger || exponent.isNegative) {
          if (base.degree > 0) return null;
          final value = exactRational(node);
          return value == null ? null : Poly.constant(value);
        }
        final power = exponent.numerator.toInt();
        if (base.degree > 0 && base.degree * power > maxDegree) {
          throw const MathInputError('number_too_large', detail: 'degree');
        }
        var result = Poly.constant(Rational.one);
        for (var i = 0; i < power; i++) {
          result = result * base;
        }
        return result;
    }
  }

  /// This polynomial as a display tree in descending powers of [variable].
  Node toNode(String variable) {
    if (isZero) return const Num('0');
    Node? result;
    for (var power = degree; power >= 0; power--) {
      final c = coefficients[power];
      if (c.isZero) continue;
      final magnitude = _term(c.abs, power, variable);
      if (result == null) {
        result = c.isNegative ? Neg(magnitude) : magnitude;
      } else {
        result = c.isNegative ? Sub(result, magnitude) : Add(result, magnitude);
      }
    }
    return result!;
  }

  static Node _term(Rational magnitude, int power, String variable) {
    if (power == 0) return rationalNode(magnitude);
    final Node x = power == 1 ? Var(variable) : Pow(Var(variable), Num('$power'));
    if (magnitude == Rational.one) return x;
    return Mul(rationalNode(magnitude), x);
  }
}

/// A non-negative rational as a display tree: `3` or `3/4`.
Node rationalNode(Rational magnitude) {
  if (magnitude.isInteger) return Num('${magnitude.numerator}');
  return Div(Num('${magnitude.numerator}'), Num('${magnitude.denominator}'));
}

/// Any rational as a display tree, with a leading minus when negative.
Node signedRationalNode(Rational value) =>
    value.isNegative ? Neg(rationalNode(value.abs)) : rationalNode(value);

extension PolyCalculus on Poly {
  Poly derivative() => Poly([
        for (var power = 1; power < coefficients.length; power++)
          coefficients[power] * Rational.fromInt(power),
      ]);

  /// The antiderivative with constant term zero.
  Poly integral() => Poly([
        Rational.zero,
        for (var power = 0; power < coefficients.length; power++)
          coefficients[power] / Rational.fromInt(power + 1),
      ]);

  /// Quotient and remainder of division by a non-zero [divisor].
  (Poly, Poly) divmod(Poly divisor) {
    if (divisor.isZero) throw ArgumentError('Division by the zero polynomial.');
    if (degree < divisor.degree) return (Poly(const []), this);
    final remainder = List<Rational>.of(coefficients);
    final quotient = List<Rational>.filled(
      degree - divisor.degree + 1,
      Rational.zero,
    );
    final lead = divisor.coefficients.last;
    for (var i = degree - divisor.degree; i >= 0; i--) {
      final factor = remainder[i + divisor.degree] / lead;
      quotient[i] = factor;
      for (var j = 0; j <= divisor.degree; j++) {
        remainder[i + j] = remainder[i + j] - factor * divisor.coefficients[j];
      }
    }
    return (Poly(quotient), Poly(remainder.sublist(0, divisor.degree)));
  }

  /// Same roots, integer coefficients with no common factor, positive lead.
  Poly primitive() {
    if (isZero) return this;
    var common = BigInt.one;
    for (final c in coefficients) {
      common = lcmOf(common, c.denominator);
    }
    final integers = [
      for (final c in coefficients) c.numerator * (common ~/ c.denominator),
    ];
    var divisor = BigInt.zero;
    for (final n in integers) {
      divisor = divisor.gcd(n);
    }
    if (integers.last.isNegative) divisor = -divisor;
    return Poly([for (final n in integers) Rational(n ~/ divisor)]);
  }
}

/// Number of distinct real roots, by Sturm's theorem. Exact.
int distinctRealRootCount(Poly f) {
  if (f.degree < 1) return 0;
  final sequence = <Poly>[f, f.derivative()];
  while (true) {
    final (_, remainder) =
        sequence[sequence.length - 2].divmod(sequence.last);
    if (remainder.isZero) break;
    sequence.add(-remainder);
  }
  int signChanges({required bool atPlusInfinity}) {
    var changes = 0;
    int? previous;
    for (final p in sequence) {
      var sign = p.coefficients.last.isNegative ? -1 : 1;
      if (!atPlusInfinity && p.degree.isOdd) sign = -sign;
      if (previous != null && sign != previous) changes++;
      previous = sign;
    }
    return changes;
  }

  return signChanges(atPlusInfinity: false) - signChanges(atPlusInfinity: true);
}

const int _maxCoefficientForRoots = 1000000000000;
const int _maxCandidatePairs = 20000;

List<int> _divisors(BigInt value) {
  if (value > BigInt.from(_maxCoefficientForRoots)) {
    throw const UnsupportedProblem('needs_full_engine',
        detail: 'coefficient too large');
  }
  final n = value.toInt();
  final small = <int>[];
  final large = <int>[];
  for (var i = 1; i * i <= n; i++) {
    if (n % i == 0) {
      small.add(i);
      if (i * i != n) large.add(n ~/ i);
    }
  }
  return [...small, ...large.reversed];
}

/// Every rational root of [f] with its multiplicity (ascending), and what is
/// left of [f] after dividing them out.
(List<(Rational, int)>, Poly) splitRationalRoots(Poly f) {
  var remaining = f;
  final found = <(Rational, int)>[];

  var zeroMultiplicity = 0;
  while (remaining.degree > 0 && remaining.coefficient(0).isZero) {
    remaining = Poly(remaining.coefficients.sublist(1));
    zeroMultiplicity++;
  }
  if (zeroMultiplicity > 0) found.add((Rational.zero, zeroMultiplicity));

  if (remaining.degree >= 1) {
    final integer = remaining.primitive();
    final constants = _divisors(integer.coefficient(0).numerator.abs());
    final leads = _divisors(integer.coefficients.last.numerator.abs());
    if (constants.length * leads.length > _maxCandidatePairs) {
      throw const UnsupportedProblem('needs_full_engine',
          detail: 'too many candidates');
    }
    final candidates = <Rational>{
      for (final p in constants)
        for (final q in leads) ...[
          Rational(BigInt.from(p), BigInt.from(q)),
          Rational(BigInt.from(-p), BigInt.from(q)),
        ],
    }.toList()
      ..sort();
    for (final candidate in candidates) {
      var multiplicity = 0;
      while (remaining.degree >= 1 && remaining.evaluate(candidate).isZero) {
        remaining =
            remaining.divmod(Poly([-candidate, Rational.one])).$1;
        multiplicity++;
      }
      if (multiplicity > 0) found.add((candidate, multiplicity));
    }
  }
  found.sort((x, y) => x.$1.compareTo(y.$1));
  return (found, remaining);
}

/// [p] written as a product: constant × (q·x − p)^k … × remaining factor.
///
/// Each rational root p/q contributes the integer factor (q·x − p), so
/// 6x² + x − 2 becomes (3x + 2)(2x − 1), not 6(x + 2/3)(x − 1/2).
Node factoredNode(
  Poly p,
  String variable,
  List<(Rational, int)> roots,
  Poly remainder,
) {
  final factors = <Node>[];
  var leadProduct = Rational.one;
  for (final (root, multiplicity) in roots) {
    final q = Rational(root.denominator);
    final linear = Poly([-Rational(root.numerator), q]).toNode(variable);
    factors.add(
      multiplicity == 1 ? linear : Pow(linear, Num('$multiplicity')),
    );
    leadProduct = leadProduct * q.pow(multiplicity);
  }
  if (remainder.degree >= 1) {
    final rest = remainder.primitive();
    factors.add(rest.toNode(variable));
    leadProduct = leadProduct * rest.coefficients.last;
  }
  if (factors.isEmpty) return p.toNode(variable);
  final product = factors.reduce(Mul.new);
  final constant = p.coefficients.last / leadProduct;
  if (constant == Rational.one) return product;
  if (constant == -Rational.one) return Neg(product);
  final scaled = Mul(rationalNode(constant.abs), product);
  return constant.isNegative ? Neg(scaled) : scaled;
}
