import 'package:abqari_engine/abqari_engine.dart';
import 'package:test/test.dart';

String tree(String text) => parse(normalize(text).text).toString();

void main() {
  group('normalisation', () {
    const cases = {
      '٢س + ٣ = ٧': '2x + 3 = 7',
      '3×4÷2−1': '3*4/2-1',
      'x² − 5x + 6': 'x^(2) - 5x + 6',
      '√9': 'sqrt(9)',
      '√(x+1)': 'sqrt(x+1)',
      'جتا(س) + جا(ص)': 'cos(x) + sin(y)',
      'لو(100) + لط(ن)': 'log(100) + ln(n)',
      'جذر(16)': 'sqrt(16)',
      '2π': '2pi',
      '3 ≤ 5': '3 <= 5',
      '٣٫٥': '3.5',
      '2‏+‫3': '2+3',
      'سَ + ١': 'x + 1',
    };
    cases.forEach((raw, canonical) {
      test(raw, () => expect(normalize(raw).text, canonical));
    });

    test('reads a leading instruction word', () {
      expect(normalize('حل: 2x + 3 = 7').task, 'solve');
      expect(normalize('حلل س² − ٩').task, 'factor');
      expect(normalize('اشتق جا(س)').task, 'differentiate');
      expect(normalize('derivative of x^3').task, 'differentiate');
      expect(normalize('2x + 3 = 7').task, isNull);
    });
  });

  group('parsing', () {
    const structure = {
      '2 + 3 * 4': '(add 2 (mul 3 4))',
      '10 - 2 - 3': '(sub (sub 10 2) 3)',
      '2^3^2': '(pow 2 (pow 3 2))',
      '-x^2': '(neg (pow x 2))',
      '-2x + 3': '(add (neg (mul 2 x)) 3)',
      '2^-1': '(pow 2 (neg 1))',
      '2(x + 1)': '(mul 2 (add x 1))',
      '(x + 1)(x - 1)': '(mul (add x 1) (sub x 1))',
      'x sin(x)': '(mul x (sin x))',
      '1/2x': '(mul (div 1 2) x)',
      'pi r^2': '(mul pi (pow r 2))',
    };
    structure.forEach((text, expected) {
      test(text, () => expect(tree(text), expected));
    });

    const rejections = {
      '': 'empty',
      '2 +': 'incomplete',
      '2 3': 'missing_operator',
      'x2': 'missing_operator',
      'sinx': 'function_needs_parentheses',
      '(2 + 3': 'unbalanced_parentheses',
      '1,5': 'comma_not_supported',
      '2..3': 'bad_number',
      '2 = 3 = 4': 'chained_relation',
      'hello': 'unknown_word',
      'مرحبا': 'unknown_word',
      'a\$b': 'unknown_symbol',
    };
    rejections.forEach((text, code) {
      test('rejects "$text"', () {
        expect(
          () => tree(text),
          throwsA(isA<MathInputError>().having((e) => e.code, 'code', code)),
        );
      });
    });

    test('rejects deep nesting and long input', () {
      expect(() => tree('${'(' * 100}1${')' * 100}'),
          throwsA(isA<MathInputError>().having((e) => e.code, 'code', 'too_deep')));
      expect(() => tree('x' * 501),
          throwsA(isA<MathInputError>().having((e) => e.code, 'code', 'too_long')));
    });

    for (final hostile in [
      "__import__('os').system('id')",
      'x.__class__',
      'lambda x: x',
      '[1, 2, 3]',
      "'a'",
      'x; y',
      'print(1)',
    ]) {
      test('code is never accepted as mathematics: $hostile', () {
        expect(() => tree(hostile), throwsA(isA<MathInputError>()));
      });
    }
  });
}
