/// An exact fraction of arbitrary size. Always in lowest terms, denominator > 0.
class Rational implements Comparable<Rational> {
  Rational._(this.numerator, this.denominator);

  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var n = numerator;
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) {
      throw ArgumentError('A rational cannot have a zero denominator.');
    }
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final divisor = n.gcd(d);
    if (divisor > BigInt.one) {
      n = n ~/ divisor;
      d = d ~/ divisor;
    }
    return Rational._(n, d);
  }

  factory Rational.fromInt(int value) => Rational(BigInt.from(value));

  /// Parses a non-negative decimal literal such as `12` or `12.5` exactly.
  factory Rational.parse(String decimal) {
    final dot = decimal.indexOf('.');
    if (dot < 0) return Rational(BigInt.parse(decimal));
    final fraction = decimal.substring(dot + 1);
    return Rational(
      BigInt.parse(decimal.substring(0, dot) + fraction),
      BigInt.from(10).pow(fraction.length),
    );
  }

  static final Rational zero = Rational.fromInt(0);
  static final Rational one = Rational.fromInt(1);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;
  bool get isInteger => denominator == BigInt.one;
  Rational get abs => isNegative ? -this : this;

  Rational get inverse {
    if (isZero) throw ArgumentError('Zero has no inverse.');
    return Rational(denominator, numerator);
  }

  Rational operator +(Rational other) => Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator -(Rational other) => this + (-other);

  Rational operator -() => Rational._(-numerator, denominator);

  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);

  Rational operator /(Rational other) => this * other.inverse;

  Rational pow(int exponent) {
    if (exponent >= 0) {
      return Rational._(numerator.pow(exponent), denominator.pow(exponent));
    }
    return inverse.pow(-exponent);
  }

  double toDouble() => numerator / denominator;

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

/// Integer square root: the largest `r` with `r * r <= value`.
BigInt integerSqrt(BigInt value) {
  if (value.isNegative) throw ArgumentError('Negative value.');
  if (value < BigInt.two) return value;
  var x = BigInt.one << ((value.bitLength + 1) ~/ 2);
  while (true) {
    final next = (x + value ~/ x) >> 1;
    if (next >= x) return x;
    x = next;
  }
}

/// The exact square root of [value] when it is a perfect square, else null.
Rational? exactSqrt(Rational value) {
  if (value.isNegative) return null;
  final n = integerSqrt(value.numerator);
  final d = integerSqrt(value.denominator);
  if (n * n == value.numerator && d * d == value.denominator) {
    return Rational(n, d);
  }
  return null;
}

extension RationalSign on Rational {
  /// -1, 0 or 1.
  int get sign => numerator.sign;
}

/// Splits a positive integer as `k² · m` with `m` square-free. Returns (k, m).
///
/// Trial division up to 100 000; a larger leftover factor is kept in `m`
/// (still exact, possibly not fully simplified) unless it is a perfect square.
(BigInt, BigInt) squarefreeParts(BigInt n) {
  if (n <= BigInt.zero) throw ArgumentError('Expected a positive integer.');
  var rest = n;
  var k = BigInt.one;
  var m = BigInt.one;
  var p = BigInt.two;
  final limit = BigInt.from(100000);
  while (p * p <= rest && p <= limit) {
    var exponent = 0;
    while (rest % p == BigInt.zero) {
      rest = rest ~/ p;
      exponent++;
    }
    k *= p.pow(exponent ~/ 2);
    if (exponent.isOdd) m *= p;
    p += p == BigInt.two ? BigInt.one : BigInt.two;
  }
  if (rest > BigInt.one) {
    final root = integerSqrt(rest);
    if (root * root == rest) {
      k *= root;
    } else {
      m *= rest;
    }
  }
  return (k, m);
}

/// √value = s·√m with s rational and m a square-free positive integer
/// (m == 1 when value is a perfect square). Requires value ≥ 0.
(Rational, BigInt) sqrtParts(Rational value) {
  if (value.isNegative) throw ArgumentError('Negative value.');
  if (value.isZero) return (Rational.zero, BigInt.one);
  // √(p/q) = √(p·q) / q
  final (k, m) = squarefreeParts(value.numerator * value.denominator);
  return (Rational(k, value.denominator), m);
}

BigInt lcmOf(BigInt a, BigInt b) => a ~/ a.gcd(b) * b;
