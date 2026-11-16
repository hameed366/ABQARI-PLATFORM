import 'package:abqari_engine/abqari_engine.dart';

import 'bilingual.dart';
import 'model.dart';
import 'practice.dart';

enum Verdict { correct, incorrect, unreadable, wrongForm }

/// The result of checking one answer. [messageCode] explains anything other
/// than a plain right or wrong (see [markingMessages]).
class Marking {
  const Marking(this.verdict, [this.messageCode]);

  final Verdict verdict;
  final String? messageCode;

  bool get isCorrect => verdict == Verdict.correct;

  /// Counts towards mastery: unreadable answers are not held against anyone.
  bool get counts => verdict == Verdict.correct || verdict == Verdict.incorrect;
}

const Map<String, Bilingual> markingMessages = {
  'answer_empty': Bilingual('اكتب إجابتك أولًا.', 'Type your answer first.'),
  'answer_unreadable': Bilingual(
    'لم أستطع قراءة الإجابة. اكتب عددًا أو عبارة رياضية.',
    'I could not read that answer. Type a number or an expression.',
  ),
  'answer_not_expanded': Bilingual(
    'القيمة صحيحة، لكن المطلوب فك الأقواس كلها.',
    'The value is right, but every bracket must be multiplied out.',
  ),
  'answer_not_factored': Bilingual(
    'القيمة صحيحة، لكن المطلوب كتابتها حاصل ضرب عوامل.',
    'The value is right, but it must be written as a product of factors.',
  ),
};

/// Separators between several solutions: comma, Arabic comma, semicolon, "or", "أو".
final RegExp _separators = RegExp(r'\s*(?:,|،|;|؛)\s*|\s+(?:or|أو)\s+');

/// Marks [answer] against the engine's verified solution of [question].
///
/// Comparison is exact: `0.5` and `1/2` are the same answer; `0.33` is not
/// `1/3`. Order of solutions does not matter; repeating one does not count twice.
Marking mark(Question question, String answer) {
  final text = answer.trim();
  if (text.isEmpty) return const Marking(Verdict.unreadable, 'answer_empty');
  final solved = question.result.answer!;
  switch (question.form) {
    case ExpectedForm.solutions:
      final values = <Surd>[];
      for (final part in text.split(_separators)) {
        if (part.trim().isEmpty) continue;
        final value = _constant(part, question.result.variable);
        if (value == null) return const Marking(Verdict.unreadable, 'answer_unreadable');
        if (!values.contains(value)) values.add(value);
      }
      if (values.isEmpty) return const Marking(Verdict.unreadable, 'answer_unreadable');
      final expected = solved.roots;
      final same = values.length == expected.length && expected.every(values.contains);
      return Marking(same ? Verdict.correct : Verdict.incorrect);

    case ExpectedForm.value:
      final value = _constant(text, null);
      if (value == null) return const Marking(Verdict.unreadable, 'answer_unreadable');
      return Marking(value == solved.exact ? Verdict.correct : Verdict.incorrect);

    case ExpectedForm.expanded:
    case ExpectedForm.factored:
      final variable = question.result.variable ?? 'x';
      final Node tree;
      try {
        final statement = parse(normalize(text).text);
        if (statement.relation != null) {
          return const Marking(Verdict.unreadable, 'answer_unreadable');
        }
        tree = statement.lhs;
        checkSize(tree);
      } on MathInputError {
        return const Marking(Verdict.unreadable, 'answer_unreadable');
      } on MathDomainError {
        return const Marking(Verdict.incorrect);
      }
      final names = variablesOf(tree);
      if (names.any((name) => name != variable)) return const Marking(Verdict.incorrect);
      final mine = Poly.fromNode(tree, variable);
      final theirs = Poly.fromNode(solved.expression!, variable);
      if (mine == null || theirs == null || mine != theirs) {
        return const Marking(Verdict.incorrect);
      }
      if (question.form == ExpectedForm.expanded && !isExpanded(tree)) {
        return const Marking(Verdict.wrongForm, 'answer_not_expanded');
      }
      if (question.form == ExpectedForm.factored && !isFactored(tree)) {
        return const Marking(Verdict.wrongForm, 'answer_not_factored');
      }
      return const Marking(Verdict.correct);
  }
}

/// An exact constant from one typed answer, accepting a leading `x =`.
Surd? _constant(String part, String? variable) {
  try {
    final statement = parse(normalize(part).text);
    Node tree = statement.lhs;
    if (statement.relation != null) {
      final lhs = statement.lhs;
      if (statement.relation != '=' || lhs is! Var || (variable != null && lhs.name != variable)) {
        return null;
      }
      tree = statement.rhs!;
    }
    if (variablesOf(tree).isNotEmpty) return null;
    checkSize(tree);
    checkRealDomain(tree);
    return constantSurd(tree);
  } on MathInputError {
    return null;
  } on MathDomainError {
    return null;
  }
}

/// No bracket containing the variable is multiplied, divided or raised.
bool isExpanded(Node node) => switch (node) {
      Add(:final left, :final right) || Sub(:final left, :final right) =>
        isExpanded(left) && isExpanded(right),
      Neg(:final operand) => isExpanded(operand),
      Mul(:final left, :final right) ||
      Div(:final left, :final right) ||
      Pow(:final left, :final right) =>
        _monomialFactor(left) && _monomialFactor(right),
      _ => true,
    };

bool _monomialFactor(Node node) => switch (node) {
      Add() || Sub() => variablesOf(node).isEmpty,
      Neg(:final operand) => _monomialFactor(operand),
      Mul(:final left, :final right) ||
      Div(:final left, :final right) ||
      Pow(:final left, :final right) =>
        _monomialFactor(left) && _monomialFactor(right),
      _ => true,
    };

/// A product with at least two factors that contain the variable
/// (a repeated factor such as `(x + 3)^2` counts twice).
bool isFactored(Node node) {
  final root = node is Neg ? node.operand : node;
  var count = 0;
  void collect(Node n) {
    switch (n) {
      case Mul(:final left, :final right):
        collect(left);
        collect(right);
      case Pow(:final left, :final right) when variablesOf(left).isNotEmpty:
        final exponent = exactRational(right);
        count += exponent != null && exponent.isInteger ? exponent.numerator.toInt() : 1;
      case Neg(:final operand):
        collect(operand);
      default:
        if (variablesOf(n).isNotEmpty) count++;
    }
  }

  if (root is! Mul && root is! Pow) return false;
  collect(root);
  return count >= 2;
}
