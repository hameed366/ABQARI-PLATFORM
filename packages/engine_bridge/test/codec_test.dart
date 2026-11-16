import 'package:abqari_bridge/abqari_bridge.dart';
import 'package:abqari_engine/abqari_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> solved(String task, Map<String, dynamic> answer, {String normalized = 'x'}) => {
      'engine_version': '0.1.0',
      'input': {'raw': 'raw text', 'normalized': normalized},
      'status': 'solved',
      'task': task,
      'answer': answer,
      'notes': [
        {'code': 'log_is_base_ten', 'ar': '…', 'en': '…'},
      ],
      'verification': {
        'status': 'verified',
        'checks': [
          {'name': 'high_precision_numeric', 'passed': true, 'detail': 'agree'},
        ],
        'summary': {'code': 'verification_verified', 'ar': '…', 'en': '…'},
      },
    };

void main() {
  group('trees', () {
    test('every node kind decodes', () {
      final node = nodeFromJson([
        'add',
        ['mul', ['num', '2'], ['call', 'sin', ['var', 'x']]],
        ['div', ['neg', ['const', 'pi']], ['pow', ['num', '1.5'], ['var', 'y']]],
      ]);
      expect(sexpr(node), '(add (mul 2 (sin x)) (div (neg pi) (pow 1.5 y)))');
    });

    for (final bad in <Object?>[
      null,
      [],
      ['frobnicate', 1],
      ['num', '1e5'],
      ['num', '-3'],
      ['var', 'xy'],
      ['var', 'X'],
      ['const', 'tau'],
      ['call', 'asin', ['var', 'x']],
      ['add', ['num', '1']],
      ['num', 3],
    ]) {
      test('rejects $bad', () {
        expect(() => nodeFromJson(bad), throwsFormatException);
      });
    }

    test('rejects absurdly deep trees', () {
      Object deep = ['num', '1'];
      for (var i = 0; i < 300; i++) {
        deep = ['neg', deep];
      }
      expect(() => nodeFromJson(deep), throwsFormatException);
    });
  });

  group('results', () {
    test('a value with its decimal approximation', () {
      final result = solveResultFromJson(solved('evaluate', {
        'plain': '1/2',
        'approx': '0.500000000000',
        'tree': ['div', ['num', '1'], ['num', '2']],
      }, normalized: 'sin(pi/6)'));
      expect(result.status, SolveStatus.solved);
      expect(result.understood.toString(), '(sin (div pi 6))');
      expect(sexpr(result.answer!.expression!), '(div 1 2)');
      expect(result.answer!.approximation, 0.5);
      expect(result.verification!.status, VerificationStatus.verified);
      expect(result.notes, ['log_is_base_ten']);
    });

    test('solutions keep order, trees and approximations', () {
      final result = solveResultFromJson(solved('solve_equation', {
        'kind': 'finite',
        'solutions': [
          {'plain': '3', 'tree': ['num', '3']},
          {'plain': 'log(5)/log(2)', 'approx': '2.32192809489', 'tree': ['call', 'ln', ['num', '5']]},
        ],
      }, normalized: '2^x = 8'));
      final answer = result.answer!;
      expect(answer.solutionSet, SolutionSet.finite);
      expect(answer.rootNodes.map(sexpr), ['3', '(ln 5)']);
      expect(answer.rootApproximations, [null, 2.32192809489]);
    });

    test('an answer without a tree falls back to its plain text', () {
      final result = solveResultFromJson(solved('differentiate', {'plain': 'asin(x)', 'tree': null}));
      expect(result.answer!.expression, isA<Sym>());
      expect((result.answer!.expression! as Sym).symbol, 'asin(x)');
    });

    test('integrals carry the constant of integration', () {
      final result = solveResultFromJson(solved('integrate', {
        'plain': 'sin(x) + C',
        'tree': ['call', 'sin', ['var', 'x']],
        'constant_of_integration': true,
      }));
      expect(result.answer!.constantOfIntegration, isTrue);
    });

    test('statuses other than solved keep the error', () {
      final result = solveResultFromJson({
        'input': {'raw': 'x + y = 3', 'normalized': 'x + y = 3'},
        'status': 'unsupported',
        'error': {'code': 'multiple_variables', 'ar': '…', 'en': '…', 'detail': null},
      });
      expect(result.status, SolveStatus.unsupported);
      expect(result.errorCode, 'multiple_variables');
      expect(result.answer, isNull);
    });

    test('malformed answers are rejected, never shown', () {
      expect(() => solveResultFromJson({'status': 'great'}), throwsFormatException);
      expect(
        () => solveResultFromJson(solved('evaluate', {'tree': ['num', 'NaN']})),
        throwsFormatException,
      );
      expect(
        () => solveResultFromJson(solved('teleport', {'tree': ['num', '1']})),
        throwsFormatException,
      );
    });
  });
}
