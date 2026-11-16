import 'errors.dart';
import 'nodes.dart';

/// A small hand-written parser. Nothing a user types is ever executed.
///
/// Grammar (implicit multiplication allowed: 2x, 2(x+1), (x+1)(x-1), x sin(x)):
///
///     statement := expr (RELOP expr)?
///     expr      := ["+" | "-"] term (("+" | "-") term)*
///     term      := factor (("*" | "/") factor | power)*
///     factor    := ("+" | "-") factor | power
///     power     := primary ("^" factor)?
///     primary   := NUMBER | CONST | VAR | FUNC "(" expr ")" | "(" expr ")"
///
/// So -x^2 = -(x^2), -2x = -(2x), 2^-1 = 1/2, 2^3^2 = 2^(3^2), 1/2x = (1/2)·x.
const List<String> functionNames = [
  'sqrt',
  'sin',
  'cos',
  'tan',
  'log',
  'ln',
  'exp',
  'abs',
];
const List<String> relationSymbols = ['<=', '>=', '!=', '=', '<', '>'];
const int maxDepth = 60;
const int maxAdjacentVariables = 3;

// Longest first.
const List<String> _names = ['sqrt', 'sin', 'cos', 'tan', 'log', 'exp', 'abs', 'ln', 'pi'];
final RegExp _number = RegExp(r'\d+(?:\.\d+)?');

enum _Kind { number, variable, constant, function, operator, relation, open, close, end }

class _Token {
  const _Token(this.kind, this.text, this.position);
  final _Kind kind;
  final String text;
  final int position;
}

bool _isLower(String char) {
  final unit = char.codeUnitAt(0);
  return unit >= 0x61 && unit <= 0x7A;
}

bool _isDigit(String char) {
  final unit = char.codeUnitAt(0);
  return unit >= 0x30 && unit <= 0x39;
}

/// Rejects ordinary words: "xyz" is a product of variables, "hello" is not maths.
void _checkLetterRun(String run, int position) {
  var remaining = run;
  for (final name in _names) {
    remaining = remaining.replaceAll(name, ' ');
  }
  for (final part in remaining.split(' ')) {
    if (part.length > maxAdjacentVariables) {
      throw MathInputError('unknown_word', position: position, detail: run);
    }
  }
}

List<_Token> _tokenize(String text) {
  final tokens = <_Token>[];
  var i = 0;
  var letterRunEnd = 0;
  while (i < text.length) {
    final char = text[i];
    if (char == ' ') {
      i++;
      continue;
    }
    if (_isDigit(char)) {
      final match = _number.matchAsPrefix(text, i)!;
      tokens.add(_Token(_Kind.number, match[0]!, i));
      i = match.end;
      if (i < text.length && text[i] == '.') {
        throw MathInputError('bad_number', position: i);
      }
      continue;
    }
    if (char == '.') throw MathInputError('bad_number', position: i);
    if (_isLower(char)) {
      if (i >= letterRunEnd) {
        var end = i;
        while (end < text.length && _isLower(text[end])) {
          end++;
        }
        _checkLetterRun(text.substring(i, end), i);
        letterRunEnd = end;
      }
      final name = _names.where((name) => text.startsWith(name, i)).firstOrNull;
      if (name != null) {
        tokens.add(_Token(name == 'pi' ? _Kind.constant : _Kind.function, name, i));
        i += name.length;
      } else {
        tokens.add(_Token(char == 'e' ? _Kind.constant : _Kind.variable, char, i));
        i++;
      }
      continue;
    }
    final relation =
        relationSymbols.where((symbol) => text.startsWith(symbol, i)).firstOrNull;
    if (relation != null) {
      tokens.add(_Token(_Kind.relation, relation, i));
      i += relation.length;
      continue;
    }
    if ('+-*/^'.contains(char)) {
      tokens.add(_Token(_Kind.operator, char, i));
    } else if (char == '(') {
      tokens.add(_Token(_Kind.open, char, i));
    } else if (char == ')') {
      tokens.add(_Token(_Kind.close, char, i));
    } else {
      throw MathInputError('unknown_symbol', position: i, detail: char);
    }
    i++;
  }
  tokens.add(_Token(_Kind.end, '', text.length));
  return tokens;
}

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  int _index = 0;
  int _depth = 0;

  _Token get _current => _tokens[_index];

  _Token _advance() => _tokens[_index++];

  bool _isOperator(String symbols) =>
      _current.kind == _Kind.operator && symbols.contains(_current.text);

  Statement statement() {
    final lhs = _expr();
    if (_current.kind == _Kind.relation) {
      final relation = _advance().text;
      final rhs = _expr();
      if (_current.kind == _Kind.relation) {
        throw MathInputError('chained_relation', position: _current.position);
      }
      _expectEnd();
      return Statement(lhs, relation, rhs);
    }
    _expectEnd();
    return Statement(lhs);
  }

  void _expectEnd() {
    final token = _current;
    if (token.kind == _Kind.close) {
      throw MathInputError('unbalanced_parentheses', position: token.position);
    }
    if (token.kind != _Kind.end) {
      throw MathInputError('unexpected_token',
          position: token.position, detail: token.text);
    }
  }

  Node _expr() {
    _depth++;
    if (_depth > maxDepth) {
      throw MathInputError('too_deep', position: _current.position);
    }
    Node node;
    if (_isOperator('-')) {
      _advance();
      node = Neg(_term());
    } else {
      if (_isOperator('+')) _advance();
      node = _term();
    }
    while (_isOperator('+-')) {
      final isAdd = _advance().text == '+';
      final right = _term();
      node = isAdd ? Add(node, right) : Sub(node, right);
    }
    _depth--;
    return node;
  }

  Node _term() {
    var node = _factor();
    while (true) {
      if (_isOperator('*/')) {
        final isMul = _advance().text == '*';
        final right = _factor();
        node = isMul ? Mul(node, right) : Div(node, right);
      } else if (_current.kind == _Kind.variable ||
          _current.kind == _Kind.constant ||
          _current.kind == _Kind.function ||
          _current.kind == _Kind.open) {
        node = Mul(node, _power());
      } else if (_current.kind == _Kind.number) {
        // "2 3" or "x2" is far more likely a typo than a product.
        throw MathInputError('missing_operator', position: _current.position);
      } else {
        return node;
      }
    }
  }

  Node _factor() {
    if (_isOperator('-')) {
      _advance();
      return Neg(_factor());
    }
    if (_isOperator('+')) {
      _advance();
      return _factor();
    }
    return _power();
  }

  Node _power() {
    final base = _primary();
    if (_isOperator('^')) {
      _advance();
      return Pow(base, _factor());
    }
    return base;
  }

  Node _primary() {
    final token = _advance();
    switch (token.kind) {
      case _Kind.number:
        return Num(token.text);
      case _Kind.variable:
        return Var(token.text);
      case _Kind.constant:
        return Constant(token.text);
      case _Kind.function:
        if (_current.kind != _Kind.open) {
          throw MathInputError('function_needs_parentheses',
              position: token.position, detail: token.text);
        }
        _advance();
        final argument = _expr();
        _close(token.position);
        return Call(token.text, argument);
      case _Kind.open:
        final inner = _expr();
        _close(token.position);
        return inner;
      case _Kind.end:
        throw MathInputError('incomplete', position: token.position);
      case _Kind.close:
        throw MathInputError('unbalanced_parentheses', position: token.position);
      case _Kind.operator:
      case _Kind.relation:
        throw MathInputError('unexpected_token',
            position: token.position, detail: token.text);
    }
  }

  void _close(int openedAt) {
    if (_current.kind != _Kind.close) {
      throw MathInputError('unbalanced_parentheses', position: openedAt);
    }
    _advance();
  }
}

/// Parses canonical text (see `normalize`) into a [Statement].
Statement parse(String text) => _Parser(_tokenize(text)).statement();
