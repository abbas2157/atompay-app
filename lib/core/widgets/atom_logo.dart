import 'dart:math' as math;

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The AtomPay mark (handbook §4.5): a nucleus disc, two orbits and an "A".
/// [orbit] rotates the orbits for the splash animation (0…1 = one turn).
class AtomLogo extends StatelessWidget {
  const new({super.key, this.size = 44, this.orbit = 0});

  final double size;
  final double orbit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AtomPay',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AtomPainter(orbit)),
      ),
    );
  }
}

class _AtomPainter extends CustomPainter {
  const new(this.orbit);

  final double orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 20 * s, Paint()..color = AppColors.nucleus);

    final spin = orbit * 2 * math.pi;
    for (final (color, degrees) in [
      (AppColors.amber, 28.0),
      (AppColors.coral, -28.0),
    ]) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(degrees * math.pi / 180 + spin)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: 34 * s, height: 14 * s),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * s
            ..color = color,
        )
        ..restore();
    }

    final a = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          fontFamily: FontFamilies.display,
          fontWeight: FontWeight.w800,
          fontSize: 17 * s,
          color: AppColors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    a.paint(canvas, c - Offset(a.width / 2, a.height / 2));
  }

  @override
  bool shouldRepaint(_AtomPainter old) => old.orbit != orbit;
}
