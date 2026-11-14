import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/net_image.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// An eligible product: photo with the "AtomPay eligible" badge pinned to
/// its top, then brand, title, the monthly amount and the cash price
/// (brief §4). Every figure comes from the server.
class ProductCard extends StatelessWidget {
  const new({
    required this.title,
    required this.price,
    required this.monthly,
    required this.onTap,
    this.brand,
    this.imageUrl,
    super.key,
  });

  final String title;
  final String? brand;
  final int price;
  final int monthly;
  final String? imageUrl;
  final VoidCallback onTap;

  static const imageHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final radius = BorderRadius.circular(Radii.productCard);
    return Pressable(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel:
          '${brand == null ? '' : '$brand '}$title. AtomPay eligible. '
          '${rsSpoken(monthly)} per month for 3 months, no advance. '
          'Cash price ${rsSpoken(price)}.',
      excludeChildSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.white,
          border: Border.all(color: c.line),
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: c.surface,
                    child: imageUrl == null
                        ? _Placeholder(color: c.glyph)
                        : NetImage(
                            imageUrl!,
                            fallback: _Placeholder(color: c.glyph),
                          ),
                  ),
                  const Positioned(
                    left: Space.s10,
                    top: Space.s10,
                    child: AppBadge.rose('AtomPay eligible'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s14,
                Space.s12,
                Space.s14,
                Space.s14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null)
                    Text(
                      brand!.toUpperCase(),
                      style: t.xs.copyWith(letterSpacing: 0.6),
                    ),
                  const SizedBox(height: Space.s2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: Space.s8),
                  Text(rs(monthly), style: t.h3),
                  Text('per month × 3 · no advance', style: t.tiny),
                  Text(
                    'Cash price ${rs(price)}',
                    style: t.tiny.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(Icons.image_outlined, size: 40, color: color));
}

/// A [ProductCard] while it loads: the image block, then brand, title,
/// monthly amount and term lines (canvas product skeleton).
class ProductCardSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line(double widthFactor, double height, {double? radius}) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Skeleton(height: height, radius: radius ?? Radii.pill),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.white,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Skeleton(height: 140, radius: 0),
          const SizedBox(height: Space.s10),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s12,
              0,
              Space.s12,
              Space.s14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line(0.4, 10),
                const SizedBox(height: Space.s8),
                line(0.85, 12),
                const SizedBox(height: Space.s8),
                line(0.6, 16, radius: Space.s8),
                const SizedBox(height: Space.s8),
                line(0.7, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
