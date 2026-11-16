import 'package:abqari_engine/abqari_engine.dart';

import 'layout_rules.dart';
import 'notation.dart';

/// One-line text for an expression, in the logical (reading) order of the
/// notation. Used for screen readers, copying, and tests.
String mathPlainText(Node node, Notation notation) => _text(node, notation);

String statementPlainText(Statement statement, Notation notation) =>
    statement.relation == null
        ? mathPlainText(statement.lhs, notation)
        : '${mathPlainText(statement.lhs, notation)} '
            '${Notation.relation(statement.relation!)} '
            '${mathPlainText(statement.rhs!, notation)}';

String chainPlainText(EquationChain chain, Notation notation) =>
    chain.parts.map((part) => mathPlainText(part, notation)).join(' = ');

String _paren(String text) => '($text)';

String _text(Node node, Notation n) {
  switch (node) {
    case Num(:final text):
      return n.number(text);
    case Var(:final name):
      return n.variable(name);
    case Constant(:final name):
      return n.constant(name);
    case Sym(:final symbol):
      return n.symbol(symbol);
    case Neg(:final operand):
      final inner = _text(operand, n);
      return '${Notation.minus}${precedence(operand) <= 1 ? _paren(inner) : inner}';
    case Add(:final left, :final right) || Sub(:final left, :final right):
      final op = node is Add ? Notation.plus : Notation.minus;
      final r = _text(right, n);
      return '${_text(left, n)} $op ${wrapAddRight(node, right) ? _paren(r) : r}';
    case PlusMinus(:final left, :final right):
      return '${_text(left, n)} ${Notation.plusMinus} ${_text(right, n)}';
    case Mul(:final left, :final right):
      var l = _text(left, n);
      var r = _text(right, n);
      if (wrapMulOperand(left)) l = _paren(l);
      if (wrapMulOperand(right)) return '$l${_paren(r)}';
      return explicitTimes(right) ? '$l ${Notation.times} $r' : '$l$r';
    case Div(:final left, :final right):
      String part(Node p) {
        final t = _text(p, n);
        return p is Num || p is Var || p is Constant || p is Sym ? t : _paren(t);
      }
      return '${part(left)}/${part(right)}';
    case Pow(:final left, :final right):
      final base = _text(left, n);
      final exponent = _text(right, n);
      final b = wrapPowerBase(left) ? _paren(base) : base;
      final e = right is Num || right is Var ? exponent : _paren(exponent);
      return '$b^$e';
    case Call(:final function, :final argument):
      final inner = _text(argument, n);
      switch (function) {
        case 'sqrt':
          return '√${argument is Num || argument is Var ? inner : _paren(inner)}';
        case 'abs':
          return '|$inner|';
        case 'exp':
          return '${n.constant('e')}^${_paren(inner)}';
        default:
          return '${n.function(function)}${_paren(inner)}';
      }
  }
}
