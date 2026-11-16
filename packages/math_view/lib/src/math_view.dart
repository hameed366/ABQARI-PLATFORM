import 'dart:math' as math;

import 'package:abqari_engine/abqari_engine.dart';
import 'package:material_ui/material_ui.dart';

import 'layout_rules.dart';
import 'notation.dart';
import 'plain_text.dart';

/// Keys that let tests (and accessibility tools) find the parts of a drawing.
abstract final class MathViewKeys {
  static const Key base = ValueKey('math-base');
  static const Key exponent = ValueKey('math-exponent');
  static const Key radical = ValueKey('math-radical');
  static const Key numerator = ValueKey('math-numerator');
  static const Key denominator = ValueKey('math-denominator');
}

/// Draws an expression, a relation, or a chain `a = b = c` in [notation].
///
/// The drawing's direction is set by the notation, not by the surrounding
/// layout: Arabic notation always reads right to left.
class MathView extends StatelessWidget {
  const MathView._({
    super.key,
    required this.parts,
    required this.relations,
    required this.notation,
    this.fontSize,
  });

  factory MathView.expression(
    Node node, {
    Key? key,
    required Notation notation,
    double? fontSize,
  }) =>
      MathView._(
        key: key,
        parts: [node],
        relations: const [],
        notation: notation,
        fontSize: fontSize,
      );

  factory MathView.statement(
    Statement statement, {
    Key? key,
    required Notation notation,
    double? fontSize,
  }) =>
      MathView._(
        key: key,
        parts: [statement.lhs, if (statement.rhs != null) statement.rhs!],
        relations: [if (statement.relation != null) statement.relation!],
        notation: notation,
        fontSize: fontSize,
      );

  factory MathView.chain(
    EquationChain chain, {
    Key? key,
    required Notation notation,
    double? fontSize,
  }) =>
      MathView._(
        key: key,
        parts: chain.parts,
        relations: List.filled(chain.parts.length - 1, '='),
        notation: notation,
        fontSize: fontSize,
      );

  final List<Node> parts;
  final List<String> relations;
  final Notation notation;
  final double? fontSize;

  /// The same mathematics as one line of text.
  String get plainText {
    final buffer = StringBuffer(mathPlainText(parts.first, notation));
    for (var i = 0; i < relations.length; i++) {
      buffer.write(' ${Notation.relation(relations[i])} ');
      buffer.write(mathPlainText(parts[i + 1], notation));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final size = fontSize ?? math.max(style.fontSize ?? 16, 20);
    final color = style.color ?? Theme.of(context).colorScheme.onSurface;
    final painter = _MathPainter(notation, size, color);
    final children = <Widget>[painter.build(parts.first)];
    for (var i = 0; i < relations.length; i++) {
      children
        ..add(painter.operator(Notation.relation(relations[i])))
        ..add(painter.build(parts[i + 1]));
    }
    return Semantics(
      label: plainText,
      container: true,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: notation.direction,
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: size, color: color, height: 1.2),
            child: _row(children),
          ),
        ),
      ),
    );
  }
}

Widget _row(List<Widget> children,
        {CrossAxisAlignment align = CrossAxisAlignment.center}) =>
    Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: children);

class _MathPainter {
  _MathPainter(this.notation, this.size, this.color);

  final Notation notation;
  final double size;
  final Color color;

  Widget label(String value, double scale) =>
      Text(value, style: TextStyle(fontSize: size * scale), softWrap: false);

  Widget operator(String symbol, [double scale = 1]) => Padding(
        padding: EdgeInsets.symmetric(horizontal: size * scale * 0.22),
        child: label(symbol, scale),
      );

  Widget paren(Widget child, double scale) =>
      _row([label('(', scale), child, label(')', scale)]);

  Widget build(Node node, [double scale = 1]) {
    switch (node) {
      case Num(:final text):
        return label(notation.number(text), scale);
      case Var(:final name):
        return label(notation.variable(name), scale);
      case Constant(:final name):
        return label(notation.constant(name), scale);
      case Sym(:final symbol):
        return label(notation.symbol(symbol), scale);
      case Neg(:final operand):
        final inner = build(operand, scale);
        return _row([
          label(Notation.minus, scale),
          precedence(operand) <= 1 ? paren(inner, scale) : inner,
        ]);
      case Add(:final left, :final right) || Sub(:final left, :final right):
        final r = build(right, scale);
        return _row([
          build(left, scale),
          operator(node is Add ? Notation.plus : Notation.minus, scale),
          wrapAddRight(node, right) ? paren(r, scale) : r,
        ]);
      case PlusMinus(:final left, :final right):
        return _row([
          build(left, scale),
          operator(Notation.plusMinus, scale),
          build(right, scale),
        ]);
      case Mul(:final left, :final right):
        var l = build(left, scale);
        var r = build(right, scale);
        if (wrapMulOperand(left)) l = paren(l, scale);
        if (wrapMulOperand(right)) {
          r = paren(r, scale);
          return _row([l, r]);
        }
        if (explicitTimes(right)) {
          return _row([l, operator(Notation.times, scale), r]);
        }
        return _row([l, SizedBox(width: size * scale * 0.06), r]);
      case Div(:final left, :final right):
        return _fraction(left, right, scale);
      case Pow(:final left, :final right):
        return _power(left, right, scale);
      case Call(:final function, :final argument):
        switch (function) {
          case 'sqrt':
            return _radical(argument, scale);
          case 'abs':
            return _row([
              label('|', scale),
              build(argument, scale),
              label('|', scale)
            ]);
          case 'exp':
            return _power(const Constant('e'), argument, scale);
          default:
            return _row([
              label(notation.function(function), scale),
              SizedBox(width: size * scale * 0.08),
              paren(build(argument, scale), scale),
            ]);
        }
    }
  }

  Widget _fraction(Node top, Node bottom, double scale) {
    final inner = scale * 0.85;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * scale * 0.08),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: KeyedSubtree(
                    key: MathViewKeys.numerator, child: build(top, inner))),
            Container(
              height: math.max(1, size * scale * 0.06),
              margin: EdgeInsets.symmetric(vertical: size * scale * 0.06),
              color: color,
            ),
            Center(
                child: KeyedSubtree(
                    key: MathViewKeys.denominator,
                    child: build(bottom, inner))),
          ],
        ),
      ),
    );
  }

  /// In a right-to-left row the exponent, as the second child, lands on the
  /// left of its base: the Arabic convention. In Latin notation, on the right.
  Widget _power(Node baseNode, Node exponentNode, double scale) {
    var base = build(baseNode, scale);
    if (wrapPowerBase(baseNode)) base = paren(base, scale);
    return _row(
      [
        KeyedSubtree(key: MathViewKeys.base, child: base),
        Padding(
          padding: EdgeInsets.only(bottom: size * scale * 0.55),
          child: KeyedSubtree(
            key: MathViewKeys.exponent,
            child: build(exponentNode, scale * 0.62),
          ),
        ),
      ],
      align: CrossAxisAlignment.end,
    );
  }

  /// The radical sign is drawn, and mirrored in Arabic notation so that it
  /// opens to the left over its argument.
  Widget _radical(Node argument, double scale) {
    final stroke = math.max(1.2, size * scale * 0.06);
    Widget sign = CustomPaint(
      key: MathViewKeys.radical,
      painter: RadicalPainter(color: color, strokeWidth: stroke),
      child: const SizedBox.expand(),
    );
    if (notation == Notation.arabic) {
      sign = Transform.flip(flipX: true, child: sign);
    }
    return IntrinsicHeight(
      child: _row(
        [
          SizedBox(width: size * scale * 0.6, child: sign),
          Container(
            padding: EdgeInsets.only(
              top: stroke + 2,
              left: size * scale * 0.08,
              right: size * scale * 0.08,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color, width: stroke)),
            ),
            child: build(argument, scale),
          ),
        ],
        align: CrossAxisAlignment.stretch,
      ),
    );
  }
}

/// The √ sign, drawn left to right; its right end meets the bar over the
/// argument.
class RadicalPainter extends CustomPainter {
  const RadicalPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final half = strokeWidth / 2;
    final path = Path()
      ..moveTo(half, h * 0.62)
      ..lineTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.52, h - half)
      ..lineTo(w, half);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(RadicalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// A decimal approximation, at most [significant] significant digits, written
/// in [notation]'s digits. Null for values too large or small to show plainly.
String? approximateText(double value, Notation notation,
    {int significant = 10}) {
  if (value.isNaN || value.isInfinite) return null;
  if (value != 0 && (value.abs() >= 1e10 || value.abs() < 1e-6)) return null;
  var text = value.toStringAsPrecision(significant);
  if (text.contains('e')) return null;
  if (text.contains('.')) {
    text =
        text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final negative = text.startsWith('-');
  final digits = notation.number(negative ? text.substring(1) : text);
  return negative ? '${Notation.minus}$digits' : digits;
}
