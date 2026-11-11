import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

abstract final class BrandAssets {
  static const logo = 'assets/images/atompay_logo.png';
  static const mark = 'assets/images/atompay_mark.png';

  /// Ask Atom's face in every Atom app: the Atomshop app icon.
  static const atomshop = 'assets/images/atomshop_mark.png';
  static const atomseller = 'assets/images/atomseller_mark.png';
  static const atombrand = 'assets/images/atombrand_mark.png';
}

/// The AtomPay "AP" mark, on white with rounded corners.
class AtomPayMark extends StatelessWidget {
  const new({this.size = 40, this.label, super.key});

  final double size;

  /// Null hides it from screen readers (decorative).
  final String? label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.27),
    child: Image.asset(
      BrandAssets.mark,
      width: size,
      height: size,
      semanticLabel: label,
      excludeFromSemantics: label == null,
    ),
  );
}

/// The stacked logo with "Atompay / Pay in Steps".
class AtomPayLogo extends StatelessWidget {
  const new({this.height = 96, super.key});

  final double height;

  @override
  Widget build(BuildContext context) =>
      Image.asset(BrandAssets.logo, height: height, semanticLabel: 'AtomPay');
}

/// Ask Atom's avatar: the Atomshop icon on a white disc.
class AtomAvatar extends StatelessWidget {
  const new({this.size = 44, this.ring = false, super.key});

  final double size;

  /// The raised tab-bar button: border and shadow.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.white,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: c.line) : null,
        boxShadow: ring
            ? [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        BrandAssets.atomshop,
        width: size * 0.8,
        height: size * 0.8,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Home's header brand: mark, "AtomPay", "PAY IN STEPS".
class BrandHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Semantics(
      label: 'AtomPay',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AtomPayMark(size: 36),
          const SizedBox(width: Space.s10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AtomPay', style: t.h4.copyWith(height: 1.1)),
              Text('PAY IN STEPS', style: t.xs.copyWith(letterSpacing: 2.2)),
            ],
          ),
        ],
      ),
    );
  }
}
