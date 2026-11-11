import 'dart:math' as math;

import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Canvas `.two`: two fields side by side, stacked once text is large
/// enough that two columns would squeeze or overflow.
class TwoUp extends StatelessWidget {
  const new({required this.first, required this.second, super.key});

  final Widget first;
  final Widget second;

  /// True when the text scale makes side-by-side too tight.
  static bool stacked(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(10) >= 13;

  @override
  Widget build(BuildContext context) {
    if (stacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: Space.s14),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: Space.s12),
        Expanded(child: second),
      ],
    );
  }
}

/// Canvas `.spend` as a provisional limit: the server's estimate from the
/// declared income, on the AtomPay gradient (a limit card). Solid ink text.
class ProvisionalLimitCard extends StatelessWidget {
  const new({
    required this.label,
    required this.limit,
    required this.monthlyCap,
    super.key,
  });

  /// "Provisional purchase limit" or "Provisional limit".
  final String label;
  final int limit;
  final int monthlyCap;

  static const _note =
      'Final figures are set by our team after the risk assessment.';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final ink = TextStyle(color: c.ink);
    final row = t.small.merge(ink).copyWith(fontWeight: FontWeight.w700);
    return Semantics(
      container: true,
      label:
          '$label ${rsSpoken(limit)}. Up to ${rsSpoken(monthlyCap)} a month, '
          '30% of income. $_note',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.s20),
        decoration: BoxDecoration(
          gradient: c.apayGradient,
          borderRadius: BorderRadius.circular(Radii.list),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: t.tiny
                  .merge(ink)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            const SizedBox(height: Space.s6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rs(limit), style: t.display.merge(ink)),
            ),
            const SizedBox(height: Space.s12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: Space.s14,
                runSpacing: Space.s6,
                children: [
                  Text('Up to ${rs(monthlyCap)} a month', style: row),
                  Text('30% of income', style: row),
                ],
              ),
            ),
            const SizedBox(height: Space.s10),
            Text(_note, style: t.small.merge(ink)),
          ],
        ),
      ),
    );
  }
}

/// A dashed outline along a rounded rectangle (canvas `.doc`) or an oval
/// (the selfie guide).
class DashedOutlinePainter extends CustomPainter {
  const new({
    required this.color,
    this.radius = 0,
    this.strokeWidth = 1.5,
    this.dash = 4,
    this.gap = 3,
    this.oval = false,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final bool oval;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (oval) {
      path.addOval(rect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap ||
      oldDelegate.oval != oval;
}
