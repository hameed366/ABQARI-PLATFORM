import 'package:flutter/widgets.dart';

import 'abqari_colors.dart';

/// The ABQARI mark: a radical sign whose radicand is a spark, on a rounded
/// navy-to-violet tile. Drawn in code, so it is sharp at every size.
///
/// The mark is a brand symbol and is not mirrored in right-to-left layouts.
class AbqariLogo extends StatelessWidget {
  const AbqariLogo({super.key, this.size = 56, this.semanticLabel = 'ABQARI'});

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: AbqariLogoPainter()),
      ),
    );
  }
}

/// Paints the mark on a 100×100 design grid scaled to the available size.
class AbqariLogoPainter extends CustomPainter {
  const AbqariLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 100;
    canvas.save();
    canvas.scale(unit);

    const tile = Rect.fromLTWH(0, 0, 100, 100);
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AbqariColors.navy, AbqariColors.blue, AbqariColors.violet],
        stops: [0, 0.55, 1],
      ).createShader(tile);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile, const Radius.circular(22)),
      background,
    );

    final radical = Path()
      ..moveTo(18, 56)
      ..lineTo(28, 52)
      ..lineTo(40, 76)
      ..lineTo(55, 26)
      ..lineTo(84, 26);
    canvas.drawPath(
      radical,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFFFFF),
    );

    final spark = Path()
      ..moveTo(70, 40)
      ..quadraticBezierTo(71.5, 52.5, 84, 54)
      ..quadraticBezierTo(71.5, 55.5, 70, 68)
      ..quadraticBezierTo(68.5, 55.5, 56, 54)
      ..quadraticBezierTo(68.5, 52.5, 70, 40)
      ..close();
    canvas.drawPath(spark, Paint()..color = AbqariColors.glow);

    canvas.restore();
  }

  @override
  bool shouldRepaint(AbqariLogoPainter oldDelegate) => false;
}
