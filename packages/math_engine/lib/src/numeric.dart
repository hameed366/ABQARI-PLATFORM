import 'dart:math' as math;

import 'nodes.dart';

/// Floating-point value of [node] at [env], or null when it is undefined or
/// not a finite real there. Shares no code with the exact evaluators, so it is
/// used as an independent cross-check.
double? numericDouble(Node node, {Map<String, double> env = const {}}) {
  final value = _walk(node, env);
  return value == null || value.isNaN || value.isInfinite ? null : value;
}

double? _walk(Node node, Map<String, double> env) {
  switch (node) {
    case Num(:final text):
      return double.parse(text);
    case Var(:final name):
      return env[name];
    case Constant(:final name):
      return name == 'pi' ? math.pi : math.e;
    case Sym() || PlusMinus():
      return null;
    case Neg(:final operand):
      final value = _walk(operand, env);
      return value == null ? null : -value;
    case Call(:final function, :final argument):
      final value = _walk(argument, env);
      if (value == null) return null;
      return switch (function) {
        'sqrt' => value < 0 ? null : math.sqrt(value),
        'sin' => math.sin(value),
        'cos' => math.cos(value),
        'tan' => math.tan(value),
        'ln' => value <= 0 ? null : math.log(value),
        'log' => value <= 0 ? null : math.log(value) / math.ln10,
        'exp' => math.exp(value),
        'abs' => value.abs(),
        _ => null,
      };
    case Add(:final left, :final right):
      return _both(left, right, env, (a, b) => a + b);
    case Sub(:final left, :final right):
      return _both(left, right, env, (a, b) => a - b);
    case Mul(:final left, :final right):
      return _both(left, right, env, (a, b) => a * b);
    case Div(:final left, :final right):
      return _both(left, right, env, (a, b) => b == 0 ? null : a / b);
    case Pow(:final left, :final right):
      return _both(left, right, env, (a, b) {
        if (a == 0 && b < 0) return null;
        final value = math.pow(a, b).toDouble();
        return value.isNaN ? null : value;
      });
  }
}

double? _both(
  Node left,
  Node right,
  Map<String, double> env,
  double? Function(double, double) combine,
) {
  final a = _walk(left, env);
  final b = _walk(right, env);
  return a == null || b == null ? null : combine(a, b);
}

/// True when two doubles agree to about nine significant digits.
bool closeDoubles(double a, double b) =>
    (a - b).abs() <= 1e-9 * (1 + a.abs() + b.abs());
