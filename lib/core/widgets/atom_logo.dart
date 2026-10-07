import 'package:flutter/material.dart';

/// The AtomPay "AP" mark.
///
/// Brand art is raster (`assets/brand/`), so this draws the asset rather than
/// painting geometry. The navy limb would disappear on dark surfaces, so a
/// recoloured variant is used there; the coral and amber read on both.
///
/// [orbit] (0…1 = one cycle) drives a gentle breathing scale on the splash.
/// The mark has no orbits of its own, but the callers animate this value and
/// stop it when reduce-motion is on.
class AtomLogo extends StatelessWidget {
  const new({super.key, this.size = 44, this.orbit = 0});

  final double size;

  /// 0…1. Callers hold it at 0 when the mark should be still.
  final double orbit;

  /// Widest the breathing scale goes, at the midpoint of a cycle.
  static const _pulse = 0.04;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Triangle wave: 0 → 1 → 0 across one cycle, so it never jumps at the wrap.
    final phase = orbit <= 0.5 ? orbit * 2 : (1 - orbit) * 2;
    return Semantics(
      label: 'AtomPay',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Transform.scale(
          scale: 1 + _pulse * phase,
          child: Image.asset(
            dark ? 'assets/brand/mark_dark.png' : 'assets/brand/mark.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
