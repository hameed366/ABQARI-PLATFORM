import 'errors.dart';
import 'exact.dart';
import 'nodes.dart';
import 'normalize.dart';
import 'parser.dart';
import 'polynomial.dart';
import 'rational.dart';
import 'verification.dart';

const String engineVersion = '0.1.0';

/// Error code for problems this on-device engine leaves to the full engine.
const String needsFullEngine = 'needs_full_engine';

enum SolveStatus { solved, invalidInput, undefined, unsupported }

enum AnswerKind { value, truth, solutions, expression }

enum SolutionSet { finite, none, allReals }

/// One line of working: what was done ([rule]), with what ([operand]), and
/// the resulting equation(s) ([lines]).
class SolutionStep {
  const SolutionStep(this.rule, this.lines, {this.operand});

  final String rule;
  final List<EquationChain> lines;
  final Node? operand;

  String get messageCode => 'step_$rule';
}

class Answer {
  const Answer({
    required this.kind,
    this.expression,
    this.exact,
    this.truth,
    this.roots = const [],
    this.rootNodes = const [],
    this.solutionSet,
    this.constantOfIntegration = false,
  });

  final AnswerKind kind;

  /// The value (kind value) or the resulting expression (kind expression).
  final Node? expression;

  /// The exact value, for kind value.
  final Surd? exact;
  final bool? truth;

  /// Real solutions in ascending order, exact and for display.
  final List<Surd> roots;
  final List<Node> rootNodes;
  final SolutionSet? solutionSet;

  /// The expression is an antiderivative; add an arbitrary constant.
  final bool constantOfIntegration;
}

class SolveResult {
  const SolveResult({
    required this.status,
    required this.input,
    this.normalized,
    this.understood,
    this.task,
    this.variable,
    this.answer,
    this.steps = const [],
    this.verification,
    this.notes = const [],
    this.errorCode,
    this.errorPosition,
    this.errorDetail,
  });

  final SolveStatus status;
  final String input;
  final String? normalized;

  /// What the engine read, to be shown back to the user for confirmation.
  final Statement? understood;
  final String? task;
  final String? variable;
  final Answer? answer;
  final List<SolutionStep> steps;
  final Verification? verification;

  /// Message codes (see engineMessages).
  final List<String> notes;
  final String? errorCode;
  final int? errorPosition;
  final String? errorDetail;
}

class _Outcome {
  const _Outcome({
    required this.task,
    required this.answer,
    required this.verification,
    this.variable,
    this.steps = const [],
    this.notes = const [],
  });

  final String task;
  final String? variable;
  final Answer answer;
  final List<SolutionStep> steps;
  final Verification verification;
  final List<String> notes;
}

/// Solves one problem typed as text. Never throws for bad input: every
/// outcome is described by the returned [SolveResult].
SolveResult solve(String input, {String? task, String? variable}) {
  String? normalized;
  Statement? statement;
  try {
    if (task != null && !knownTasks.contains(task)) {
      throw MathInputError('unknown_task', detail: task);
    }
    if (variable != null && !_isVariableName(variable)) {
      throw MathInputError('unknown_variable', detail: variable);
    }
    final read = normalize(input);
    normalized = read.text;
    statement = parse(read.text);
    final outcome = _dispatch(statement, task ?? read.task, variable);
    return SolveResult(
      status: SolveStatus.solved,
      input: input,
      normalized: normalized,
      understood: statement,
      task: outcome.task,
      variable: outcome.variable,
      answer: outcome.answer,
      steps: outcome.steps,
      verification: outcome.verification,
      notes: outcome.notes,
    );
  } on MathInputError catch (error) {
    return SolveResult(
      status: SolveStatus.invalidInput,
      input: input,
      normalized: normalized,
      understood: statement,
      errorCode: error.code,
      errorPosition: error.position,
      errorDetail: error.detail,
    );
  } on MathDomainError catch (error) {
    return SolveResult(
      status: SolveStatus.undefined,
      input: input,
      normalized: normalized,
      understood: statement,
      errorCode: error.code,
      errorDetail: error.detail,
    );
  } on UnsupportedProblem catch (error) {
    return SolveResult(
      status: SolveStatus.unsupported,
      input: input,
      normalized: normalized,
      understood: statement,
      errorCode: error.code,
      errorDetail: error.detail,
    );
  }
}

bool _isVariableName(String name) =>
    name.length == 1 &&
    name.codeUnitAt(0) >= 0x61 &&
    name.codeUnitAt(0) <= 0x7A &&
    name != 'e';

_Outcome _dispatch(Statement statement, String? task, String? variable) {
  checkSize(statement.lhs);
  checkRealDomain(statement.lhs);
  if (statement.rhs != null) {
    checkSize(statement.rhs!);
    checkRealDomain(statement.rhs!);
  }
  if (statement.relation != null) {
    if (task != null && task != 'solve' && task != 'evaluate') {
      throw const MathInputError('relation_needs_solve');
    }
    return _solveEquation(statement, variable);
  }
  if (task == 'solve') throw const MathInputError('solve_needs_equation');
  final tree = statement.lhs;
  final hasVariables = variablesOf(tree).isNotEmpty;
  return switch (task) {
    'differentiate' => _differentiate(tree, variable),
    'integrate' => _integrate(tree, variable),
    'expand' || 'factor' => _transform(tree, task!),
    _ => hasVariables ? _transform(tree, 'simplify') : _evaluate(tree),
  };
}

String _pickVariable(Set<String> names, String? requested) {
  if (requested != null) {
    if (names.isNotEmpty && !names.contains(requested)) {
      throw MathInputError('unknown_variable', detail: requested);
    }
    return requested;
  }
  if (names.length > 1) {
    throw const UnsupportedProblem(needsFullEngine, detail: 'several variables');
  }
  return names.isEmpty ? 'x' : names.single;
}

Poly _polynomialOrUnsupported(Node node, String variable) =>
    Poly.fromNode(node, variable) ??
    (throw const UnsupportedProblem(needsFullEngine, detail: 'not a polynomial'));

// ── constants ────────────────────────────────────────────────────────────────

_Outcome _evaluate(Node tree) {
  final value = constantSurd(tree);
  if (value == null) {
    throw const UnsupportedProblem(needsFullEngine, detail: 'not exact on device');
  }
  return _Outcome(
    task: 'evaluate',
    answer: Answer(kind: AnswerKind.value, expression: surdNode(value), exact: value),
    verification: verifyEvaluation(tree, value),
  );
}

_Outcome _checkStatement(Statement statement) {
  final difference = constantSurd(Sub(statement.lhs, statement.rhs!));
  if (difference == null) {
    throw const UnsupportedProblem(needsFullEngine, detail: 'not exact on device');
  }
  final sign = difference.sign;
  final truth = switch (statement.relation) {
    '=' => sign == 0,
    '!=' => sign != 0,
    '<' => sign < 0,
    '>' => sign > 0,
    '<=' => sign <= 0,
    _ => sign >= 0,
  };
  return _Outcome(
    task: 'check_statement',
    answer: Answer(kind: AnswerKind.truth, truth: truth),
    verification: verifyStatement(statement, truth),
    notes: [truth ? 'true_statement' : 'false_statement'],
  );
}

// ── expressions in one variable ──────────────────────────────────────────────

_Outcome _transform(Node tree, String task) {
  final names = variablesOf(tree);
  if (names.isEmpty) return _evaluate(tree);
  if (names.length > 1) {
    throw const UnsupportedProblem(needsFullEngine, detail: 'several variables');
  }
  final variable = names.single;
  final polynomial = _polynomialOrUnsupported(tree, variable);
  final Node result;
  if (task == 'factor' && polynomial.degree >= 2) {
    final (roots, remainder) = splitRationalRoots(polynomial);
    if (remainder.degree >= 3) {
      throw const UnsupportedProblem(needsFullEngine,
          detail: 'factorisation beyond rational roots');
    }
    result = factoredNode(polynomial, variable, roots, remainder);
  } else {
    result = polynomial.toNode(variable);
  }
  return _Outcome(
    task: task,
    variable: variable,
    answer: Answer(kind: AnswerKind.expression, expression: result),
    verification: verifyEquivalence(tree, result, variable),
    notes: [if (sexpr(result) == sexpr(tree)) 'already_simplest'],
  );
}

_Outcome _differentiate(Node tree, String? requested) {
  final variable = _pickVariable(variablesOf(tree), requested);
  final polynomial = _polynomialOrUnsupported(tree, variable);
  final result = polynomial.derivative().toNode(variable);
  return _Outcome(
    task: 'differentiate',
    variable: variable,
    answer: Answer(kind: AnswerKind.expression, expression: result),
    verification: verifyDerivative(tree, variable, result),
    notes: const ['steps_not_available'],
  );
}

_Outcome _integrate(Node tree, String? requested) {
  final variable = _pickVariable(variablesOf(tree), requested);
  final polynomial = _polynomialOrUnsupported(tree, variable);
  final antiderivative = polynomial.integral();
  return _Outcome(
    task: 'integrate',
    variable: variable,
    answer: Answer(
      kind: AnswerKind.expression,
      expression: antiderivative.toNode(variable),
      constantOfIntegration: true,
    ),
    verification: verifyIntegral(tree, variable, antiderivative),
    notes: const ['steps_not_available'],
  );
}

// ── equations ────────────────────────────────────────────────────────────────

_Outcome _solveEquation(Statement statement, String? requested) {
  final names = {...variablesOf(statement.lhs), ...variablesOf(statement.rhs)};
  if (names.isEmpty) return _checkStatement(statement);
  if (statement.relation != '=') {
    throw const UnsupportedProblem('inequality_not_supported');
  }
  if (names.length > 1) throw const UnsupportedProblem('multiple_variables');
  final variable = _pickVariable(names, requested);
  final left = _polynomialOrUnsupported(statement.lhs, variable);
  final right = _polynomialOrUnsupported(statement.rhs!, variable);
  final difference = left - right;

  if (difference.isZero) {
    return _Outcome(
      task: 'solve_equation',
      variable: variable,
      answer: const Answer(kind: AnswerKind.solutions, solutionSet: SolutionSet.allReals),
      verification: verifyIdentity(statement, variable),
      notes: const ['all_real_numbers'],
    );
  }

  final steps = <SolutionStep>[];
  final notes = <String>[];
  final roots = <Surd>[];
  final verification = Verification();

  if (difference.degree == 0) {
    notes.add('no_real_solutions');
    steps.add(SolutionStep('move_all', [
      EquationChain([difference.toNode(variable), const Num('0')]),
    ]));
    verification.addAll(
      verifyNoSolution(statement, variable, difference.coefficient(0)),
    );
  } else if (difference.degree == 1) {
    roots.add(Surd.rational(-difference.coefficient(0) / difference.coefficient(1)));
    steps.addAll(_linearSteps(statement, left, right, variable));
  } else if (difference.degree == 2) {
    final (found, quadraticSteps, quadraticNotes) = _quadratic(difference, variable);
    roots.addAll(found);
    steps.addAll(quadraticSteps);
    notes.addAll(quadraticNotes);
  } else {
    final (rational, remainder) = splitRationalRoots(difference);
    roots.addAll([for (final (root, _) in rational) Surd.rational(root)]);
    if (remainder.degree == 2) {
      roots.addAll(_quadraticRoots(remainder));
    } else if (remainder.degree >= 3 && distinctRealRootCount(remainder) > 0) {
      throw const UnsupportedProblem(needsFullEngine,
          detail: 'irrational roots of a cubic or higher');
    }
    if (rational.isNotEmpty) {
      steps.add(SolutionStep('factorization', [
        EquationChain([
          factoredNode(difference, variable, rational, remainder),
          const Num('0'),
        ]),
      ]));
    }
    if (roots.isEmpty) notes.add('no_real_solutions');
    notes.add('steps_not_available');
  }

  roots.sort((x, y) => x.toDouble().compareTo(y.toDouble()));
  final rootNodes = [for (final root in roots) surdNode(root)];
  if (roots.isNotEmpty) {
    steps.add(SolutionStep('solutions', [
      for (final node in rootNodes) EquationChain([Var(variable), node]),
    ]));
  }
  verification.addAll(verifyRoots(statement, variable, difference, roots));
  return _Outcome(
    task: 'solve_equation',
    variable: variable,
    answer: Answer(
      kind: AnswerKind.solutions,
      roots: roots,
      rootNodes: rootNodes,
      solutionSet: roots.isEmpty ? SolutionSet.none : SolutionSet.finite,
    ),
    steps: steps,
    verification: verification,
    notes: notes,
  );
}

/// The balance method: each step keeps the equation true.
List<SolutionStep> _linearSteps(
  Statement statement,
  Poly left,
  Poly right,
  String x,
) {
  final steps = <SolutionStep>[];
  final leftNode = left.toNode(x);
  final rightNode = right.toNode(x);
  if (sexpr(leftNode) != sexpr(statement.lhs) ||
      sexpr(rightNode) != sexpr(statement.rhs!)) {
    steps.add(SolutionStep('expand_sides', [EquationChain([leftNode, rightNode])]));
  }
  final a1 = left.coefficient(1), b1 = left.coefficient(0);
  final a2 = right.coefficient(1), b2 = right.coefficient(0);
  final a = a1 - a2;
  if (!a2.isZero) {
    steps.add(SolutionStep(
      a2.isNegative ? 'add_both' : 'subtract_both',
      [EquationChain([Poly([b1, a]).toNode(x), signedRationalNode(b2)])],
      operand: Poly([Rational.zero, a2.abs]).toNode(x),
    ));
  }
  if (!b1.isZero) {
    steps.add(SolutionStep(
      b1.isNegative ? 'add_both' : 'subtract_both',
      [EquationChain([Poly([Rational.zero, a]).toNode(x), signedRationalNode(b2 - b1)])],
      operand: rationalNode(b1.abs),
    ));
  }
  if (a != Rational.one) {
    steps.add(SolutionStep(
      'divide_both',
      [EquationChain([Var(x), signedRationalNode((b2 - b1) / a)])],
      operand: signedRationalNode(a),
    ));
  }
  return steps;
}

List<Surd> _quadraticRoots(Poly f) {
  final a = f.coefficient(2), b = f.coefficient(1), c = f.coefficient(0);
  final discriminant = b * b - Rational.fromInt(4) * a * c;
  if (discriminant.isNegative) return const [];
  final twoA = Rational.fromInt(2) * a;
  if (discriminant.isZero) return [Surd.rational(-b / twoA)];
  final (s, m) = sqrtParts(discriminant);
  return [
    _normalizedSurd(-b / twoA, -s / twoA, m),
    _normalizedSurd(-b / twoA, s / twoA, m),
  ];
}

Surd _normalizedSurd(Rational a, Rational b, BigInt m) =>
    m == BigInt.one ? Surd.rational(a + b) : Surd(a, b, m);

(List<Surd>, List<SolutionStep>, List<String>) _quadratic(Poly f, String x) {
  final a = f.coefficient(2), b = f.coefficient(1), c = f.coefficient(0);
  final discriminant = b * b - Rational.fromInt(4) * a * c;
  const four = Num('4');
  const two = Num('2');
  final steps = <SolutionStep>[
    SolutionStep('standard_form', [EquationChain([f.toNode(x), const Num('0')])]),
    SolutionStep('discriminant', [
      EquationChain([
        const Sym('Δ'),
        const Sub(Pow(Var('b'), two), Mul(Mul(four, Var('a')), Var('c'))),
        Sub(
          Pow(signedRationalNode(b), two),
          Mul(Mul(four, signedRationalNode(a)), signedRationalNode(c)),
        ),
        signedRationalNode(discriminant),
      ]),
    ]),
  ];
  final notes = <String>[];
  final roots = _quadraticRoots(f);
  if (discriminant.isNegative) {
    notes.add('no_real_solutions');
  } else if (discriminant.isZero) {
    notes.add('repeated_root');
    steps.add(SolutionStep('quadratic_formula', [
      EquationChain([
        Var(x),
        const Div(Neg(Var('b')), Mul(two, Var('a'))),
        surdNode(roots.single),
      ]),
    ]));
  } else {
    steps.add(SolutionStep('quadratic_formula', [
      EquationChain([
        Var(x),
        const Div(PlusMinus(Neg(Var('b')), Call('sqrt', Sym('Δ'))), Mul(two, Var('a'))),
        Div(
          PlusMinus(signedRationalNode(-b), Call('sqrt', signedRationalNode(discriminant))),
          signedRationalNode(Rational.fromInt(2) * a),
        ),
      ]),
    ]));
    if (roots.every((root) => root.isRational)) {
      final rational = [
        for (final root in roots) (root.rationalValue, 1),
      ]..sort((p, q) => p.$1.compareTo(q.$1));
      steps.add(SolutionStep('factorization', [
        EquationChain([factoredNode(f, x, rational, Poly(const [])), const Num('0')]),
      ]));
    }
  }
  return (roots, steps, notes);
}

/// An exact value for display: an integer, a fraction, or (P ± Q√m)/R.
Node surdNode(Surd value) {
  if (value.isRational) return signedRationalNode(value.rationalValue);
  final common = lcmOf(value.a.denominator, value.b.denominator);
  final p = value.a.numerator * (common ~/ value.a.denominator);
  final q = value.b.numerator * (common ~/ value.b.denominator);
  final Node root = Call('sqrt', Num('${value.radicand}'));
  final Node irrational = q.abs() == BigInt.one ? root : Mul(Num('${q.abs()}'), root);
  final Node numerator;
  if (p == BigInt.zero) {
    numerator = q.isNegative ? Neg(irrational) : irrational;
  } else {
    final rational = signedRationalNode(Rational(p));
    numerator = q.isNegative ? Sub(rational, irrational) : Add(rational, irrational);
  }
  return common == BigInt.one ? numerator : Div(numerator, Num('$common'));
}
