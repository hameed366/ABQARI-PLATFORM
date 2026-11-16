/// The tree a typed problem is parsed into, and that every answer and step is
/// expressed in. A renderer decides how it looks (Arabic or Latin notation).
sealed class Node {
  const Node();

  @override
  String toString() => sexpr(this);
}

/// A non-negative decimal literal, kept as typed (`12`, `12.5`).
final class Num extends Node {
  const Num(this.text);
  final String text;
}

final class Var extends Node {
  const Var(this.name);
  final String name;
}

/// `pi` or `e`.
final class Constant extends Node {
  const Constant(this.name);
  final String name;
}

final class Neg extends Node {
  const Neg(this.operand);
  final Node operand;
}

final class Add extends Node {
  const Add(this.left, this.right);
  final Node left;
  final Node right;
}

final class Sub extends Node {
  const Sub(this.left, this.right);
  final Node left;
  final Node right;
}

final class Mul extends Node {
  const Mul(this.left, this.right);
  final Node left;
  final Node right;
}

final class Div extends Node {
  const Div(this.left, this.right);
  final Node left;
  final Node right;
}

final class Pow extends Node {
  const Pow(this.left, this.right);
  final Node left;
  final Node right;
}

/// sqrt, sin, cos, tan, log, ln, exp, abs.
final class Call extends Node {
  const Call(this.function, this.argument);
  final String function;
  final Node argument;
}

/// Display only: a named symbol such as Δ, or a coefficient letter in a formula.
final class Sym extends Node {
  const Sym(this.symbol);
  final String symbol;
}

/// Display only: `left ± right`.
final class PlusMinus extends Node {
  const PlusMinus(this.left, this.right);
  final Node left;
  final Node right;
}

/// A bare expression (relation == null) or `lhs relation rhs`.
class Statement {
  const Statement(this.lhs, [this.relation, this.rhs]);
  final Node lhs;
  final String? relation;
  final Node? rhs;

  @override
  String toString() =>
      relation == null ? sexpr(lhs) : '($relation ${sexpr(lhs)} ${sexpr(rhs!)})';
}

/// `a = b = c …` — one line of working.
class EquationChain {
  const EquationChain(this.parts);
  final List<Node> parts;

  @override
  String toString() => parts.map(sexpr).join(' = ');
}

/// Unambiguous structural form, e.g. `(add 2 (mul 3 x))`. Used in tests.
String sexpr(Node node) => switch (node) {
      Num(:final text) => text,
      Var(:final name) => name,
      Constant(:final name) => name,
      Sym(:final symbol) => symbol,
      Neg(:final operand) => '(neg ${sexpr(operand)})',
      Add(:final left, :final right) => '(add ${sexpr(left)} ${sexpr(right)})',
      Sub(:final left, :final right) => '(sub ${sexpr(left)} ${sexpr(right)})',
      Mul(:final left, :final right) => '(mul ${sexpr(left)} ${sexpr(right)})',
      Div(:final left, :final right) => '(div ${sexpr(left)} ${sexpr(right)})',
      Pow(:final left, :final right) => '(pow ${sexpr(left)} ${sexpr(right)})',
      PlusMinus(:final left, :final right) => '(pm ${sexpr(left)} ${sexpr(right)})',
      Call(:final function, :final argument) => '($function ${sexpr(argument)})',
    };

/// The variable letters appearing in [node].
Set<String> variablesOf(Node? node) => switch (node) {
      null || Num() || Constant() || Sym() => <String>{},
      Var(:final name) => {name},
      Neg(:final operand) => variablesOf(operand),
      Call(:final argument) => variablesOf(argument),
      Add(:final left, :final right) ||
      Sub(:final left, :final right) ||
      Mul(:final left, :final right) ||
      Div(:final left, :final right) ||
      Pow(:final left, :final right) ||
      PlusMinus(:final left, :final right) =>
        {...variablesOf(left), ...variablesOf(right)},
    };
