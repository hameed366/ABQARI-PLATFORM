import 'package:abqari_engine/abqari_engine.dart';

const Set<String> _functions = {'sqrt', 'sin', 'cos', 'tan', 'log', 'ln', 'exp', 'abs'};
final RegExp _decimal = RegExp(r'^\d+(\.\d+)?$');
const int _maxDepth = 200;

/// The expression tree sent by the full engine, as a [Node].
///
/// Throws [FormatException] for anything outside the shared vocabulary, so a
/// malformed answer is never drawn as if it were correct.
Node nodeFromJson(Object? json) => _node(json, 0);

Node _node(Object? json, int depth) {
  if (depth > _maxDepth) throw const FormatException('tree too deep');
  if (json is! List || json.isEmpty || json.first is! String) {
    throw FormatException('not a tree node: $json');
  }
  final kind = json.first as String;
  String text(int index) {
    final value = json.length > index ? json[index] : null;
    if (value is! String) throw FormatException('expected text in $json');
    return value;
  }

  Node child(int index) {
    if (json.length <= index) throw FormatException('missing operand in $json');
    return _node(json[index], depth + 1);
  }

  switch (kind) {
    case 'num':
      final value = text(1);
      if (!_decimal.hasMatch(value)) throw FormatException('bad number $value');
      return Num(value);
    case 'var':
      final name = text(1);
      if (name.length != 1 || name.compareTo('a') < 0 || name.compareTo('z') > 0) {
        throw FormatException('bad variable $name');
      }
      return Var(name);
    case 'const':
      final name = text(1);
      if (name != 'pi' && name != 'e') throw FormatException('bad constant $name');
      return Constant(name);
    case 'neg':
      return Neg(child(1));
    case 'add':
      return Add(child(1), child(2));
    case 'sub':
      return Sub(child(1), child(2));
    case 'mul':
      return Mul(child(1), child(2));
    case 'div':
      return Div(child(1), child(2));
    case 'pow':
      return Pow(child(1), child(2));
    case 'call':
      final name = text(1);
      if (!_functions.contains(name)) throw FormatException('bad function $name');
      return Call(name, child(2));
    default:
      throw FormatException('unknown node kind $kind');
  }
}
