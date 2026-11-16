import 'dart:math';

import 'package:abqari_engine/abqari_engine.dart';

import 'model.dart';

/// Builds one problem's canonical text from a random source.
typedef ProblemMaker = String Function(Random random);

/// One practice problem, already solved and verified by the engine.
class Question {
  const Question({
    required this.skill,
    required this.seed,
    required this.problem,
    required this.result,
  });

  final Skill skill;

  /// Reproduces exactly this question.
  final int seed;
  final String problem;

  /// The engine's verified solution: what the learner is marked against.
  final SolveResult result;

  ExpectedForm get form => skill.form;
}

/// Thrown when a skill's maker cannot produce a verifiable problem.
class QuestionUnavailable implements Exception {
  const QuestionUnavailable(this.skillId);
  final String skillId;

  @override
  String toString() => 'QuestionUnavailable($skillId)';
}

const int _attempts = 25;

/// A question for [skill]. Only problems the engine solved **and** verified
/// independently are ever given to a learner.
Question makeQuestion(Skill skill, int seed) {
  final random = Random(seed);
  for (var i = 0; i < _attempts; i++) {
    final problem = skill.maker(random);
    final result = solve(problem);
    if (result.status == SolveStatus.solved &&
        result.verification?.status == VerificationStatus.verified) {
      return Question(skill: skill, seed: seed, problem: problem, result: result);
    }
  }
  throw QuestionUnavailable(skill.id);
}

// ── helpers for makers ──────────────────────────────────────────────────────

/// An integer in [low, high], never one of [except].
int pick(Random random, int low, int high, {Set<int> except = const {}}) {
  while (true) {
    final value = low + random.nextInt(high - low + 1);
    if (!except.contains(value)) return value;
  }
}

/// ` + 3` or ` - 3` (nothing for zero).
String signed(int value) =>
    value == 0 ? '' : (value > 0 ? ' + $value' : ' - ${-value}');

/// `ax` written naturally: `x`, `-x`, `3x`, `-3x`.
String coefficient(int a, [String variable = 'x']) => switch (a) {
      1 => variable,
      -1 => '-$variable',
      _ => '$a$variable',
    };

/// `x^2 + bx + c` with clean signs and no zero terms.
String quadraticText(int b, int c) {
  final buffer = StringBuffer('x^2');
  if (b != 0) {
    buffer.write(b > 0 ? ' + ' : ' - ');
    buffer.write(b.abs() == 1 ? 'x' : '${b.abs()}x');
  }
  buffer.write(signed(c));
  return buffer.toString();
}
