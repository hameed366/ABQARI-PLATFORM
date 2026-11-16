import 'package:abqari_engine/abqari_engine.dart';

import 'tree_codec.dart';

const Map<String, SolveStatus> _statuses = {
  'solved': SolveStatus.solved,
  'invalid_input': SolveStatus.invalidInput,
  'undefined': SolveStatus.undefined,
  'unsupported': SolveStatus.unsupported,
};

const Map<String, SolutionSet> _solutionSets = {
  'finite': SolutionSet.finite,
  'no_real_solutions': SolutionSet.none,
  'all_real_numbers': SolutionSet.allReals,
};

/// The full engine's JSON answer as a [SolveResult] the app already knows how
/// to show. Throws [FormatException] if the answer is malformed.
SolveResult solveResultFromJson(Map<String, dynamic> json) {
  final status = _statuses[json['status']];
  if (status == null) throw FormatException('unknown status ${json['status']}');
  final input = (json['input'] as Map?)?.cast<String, dynamic>() ?? const {};
  final raw = input['raw'] as String? ?? '';
  final normalized = input['normalized'] as String?;
  final error = (json['error'] as Map?)?.cast<String, dynamic>();
  final understood = _understood(normalized);

  if (status != SolveStatus.solved) {
    return SolveResult(
      status: status,
      input: raw,
      normalized: normalized,
      understood: understood,
      errorCode: error?['code'] as String? ?? 'internal_error',
      errorPosition: error?['position'] as int?,
      errorDetail: error?['detail']?.toString(),
    );
  }

  final task = json['task'] as String?;
  final answerJson = (json['answer'] as Map).cast<String, dynamic>();
  return SolveResult(
    status: status,
    input: raw,
    normalized: normalized,
    understood: understood,
    task: task,
    variable: json['variable'] as String?,
    answer: _answer(task, answerJson),
    verification:
        _verification((json['verification'] as Map).cast<String, dynamic>()),
    notes: [
      for (final note in (json['notes'] as List? ?? const []))
        (note as Map)['code'] as String,
    ],
  );
}

Statement? _understood(String? normalized) {
  if (normalized == null) return null;
  try {
    return parse(normalized);
  } on MathInputError {
    return null;
  }
}

/// A tree when the engine sent one; otherwise the plain text, shown as-is.
Node _drawable(Map<String, dynamic> value) {
  final tree = value['tree'];
  if (tree != null) return nodeFromJson(tree);
  final plain = value['plain'];
  if (plain is String && plain.isNotEmpty) return Sym(plain);
  throw const FormatException('answer has neither a tree nor text');
}

double? _number(Object? text) => text is String ? double.tryParse(text) : null;

Answer _answer(String? task, Map<String, dynamic> answer) {
  switch (task) {
    case 'evaluate':
      return Answer(
        kind: AnswerKind.value,
        expression: _drawable(answer),
        approximation: _number(answer['approx']),
      );
    case 'check_statement':
      return Answer(kind: AnswerKind.truth, truth: answer['truth'] as bool);
    case 'solve_equation':
      final solutions = [
        for (final s in (answer['solutions'] as List? ?? const []))
          (s as Map).cast<String, dynamic>(),
      ];
      final set = _solutionSets[answer['kind']];
      if (set == null) {
        throw FormatException('unknown solution set ${answer['kind']}');
      }
      return Answer(
        kind: AnswerKind.solutions,
        solutionSet: set,
        rootNodes: [for (final s in solutions) _drawable(s)],
        rootApproximations: [for (final s in solutions) _number(s['approx'])],
      );
    case 'integrate':
      return Answer(
        kind: AnswerKind.expression,
        expression: _drawable(answer),
        constantOfIntegration: true,
      );
    case 'simplify' || 'expand' || 'factor' || 'differentiate':
      return Answer(kind: AnswerKind.expression, expression: _drawable(answer));
    default:
      throw FormatException('unknown task $task');
  }
}

Verification _verification(Map<String, dynamic> json) {
  final verification = Verification();
  for (final check in (json['checks'] as List? ?? const [])) {
    final map = (check as Map).cast<String, dynamic>();
    verification.add(
      map['name'] as String,
      map['passed'] as bool?,
      map['detail']?.toString() ?? '',
    );
  }
  return verification;
}
