import 'package:abqari_engine/abqari_engine.dart';
import 'package:test/test.dart';

Rational r(int n, [int d = 1]) => Rational(BigInt.from(n), BigInt.from(d));

Poly poly(List<int> coefficients) => Poly([for (final c in coefficients) r(c)]);

void main() {
  group('Rational', () {
    test('is always in lowest terms with a positive denominator', () {
      expect(r(6, -4).toString(), '-3/2');
      expect(r(0, 5), Rational.zero);
    });

    test('parses decimals exactly', () {
      expect(Rational.parse('0.1') + Rational.parse('0.2'), r(3, 10));
      expect(Rational.parse('12.5'), r(25, 2));
    });

    test('arithmetic and powers', () {
      expect(r(1, 2) + r(1, 3), r(5, 6));
      expect(r(2, 3).pow(-2), r(9, 4));
      expect(() => r(1).inverse * Rational.zero.inverse, throwsArgumentError);
    });

    test('square roots split into k·√m with m square-free', () {
      expect(sqrtParts(r(8)), (r(2), BigInt.from(2)));
      expect(sqrtParts(r(50)), (r(5), BigInt.from(2)));
      expect(sqrtParts(r(16)), (r(4), BigInt.one));
      expect(sqrtParts(r(1, 2)), (r(1, 2), BigInt.from(2)));
      expect(exactSqrt(r(9, 4)), r(3, 2));
      expect(exactSqrt(r(2)), isNull);
    });
  });

  group('Surd', () {
    final two = BigInt.from(2);
    test('arithmetic stays exact in Q(√m)', () {
      final root2 = Surd(Rational.zero, r(1), two);
      expect((root2 * root2).rationalValue, r(2));
      expect(((root2 + Surd(r(1), Rational.zero, two)) / root2).toString(),
          '1 + 1/2·√2');
    });

    test('sign is decided exactly', () {
      expect(Surd(r(-3, 2), r(1), two).sign, -1); // √2 < 1.5
      expect(Surd(r(-7, 5), r(1), two).sign, 1); // √2 > 1.4
      expect(Surd(r(3), r(-2), two).sign, 1); // 3 > 2√2
    });
  });

  group('Poly', () {
    test('reads polynomials from typed trees', () {
      expect(Poly.fromNode(parse(normalize('(x+1)^2').text).lhs, 'x'),
          poly([1, 2, 1]));
      expect(Poly.fromNode(parse(normalize('x/2 + 1/3').text).lhs, 'x'),
          Poly([r(1, 3), r(1, 2)]));
      expect(Poly.fromNode(parse(normalize('1/x').text).lhs, 'x'), isNull);
      expect(Poly.fromNode(parse(normalize('sin(x)').text).lhs, 'x'), isNull);
    });

    test('division with remainder', () {
      final (quotient, remainder) = poly([-1, 0, 0, 1]).divmod(poly([-1, 1]));
      expect(quotient, poly([1, 1, 1]));
      expect(remainder.isZero, isTrue);
    });

    test("Sturm's theorem counts distinct real roots", () {
      expect(distinctRealRootCount(poly([6, -5, 1])), 2); // (x-2)(x-3)
      expect(distinctRealRootCount(poly([1, 0, 1])), 0); // x² + 1
      expect(distinctRealRootCount(poly([1, 2, 1])), 1); // (x+1)²
      expect(distinctRealRootCount(poly([1, 0, 0, 0, 1])), 0); // x⁴ + 1
      expect(distinctRealRootCount(poly([-2, 0, 0, 1])), 1); // x³ − 2
      expect(distinctRealRootCount(poly([4, 0, -5, 0, 1])), 4);
    });

    test('rational roots with multiplicity', () {
      final (roots, remainder) = splitRationalRoots(poly([0, 0, -4, 0, 1]));
      expect(roots, [(r(-2), 1), (r(0), 2), (r(2), 1)]);
      expect(remainder.degree, 0);
      final (none, rest) = splitRationalRoots(poly([-2, 0, 1]));
      expect(none, isEmpty);
      expect(rest.degree, 2);
    });

    test('factor display uses integer linear factors', () {
      final p = poly([-2, 1, 6]); // 6x² + x − 2 = (3x + 2)(2x − 1)
      final (roots, remainder) = splitRationalRoots(p);
      expect(sexpr(factoredNode(p, 'x', roots, remainder)),
          '(mul (add (mul 3 x) 2) (sub (mul 2 x) 1))');
    });

    test('derivative and integral', () {
      expect(poly([0, -2, 0, 1]).derivative(), poly([-2, 0, 3]));
      expect(poly([1, 2]).integral(), poly([0, 1, 1]));
    });
  });
}
