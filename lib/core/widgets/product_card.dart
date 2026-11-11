import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
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
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                _Placeholder(color: c.glyph),
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
                    style: t.label.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Space.s8),
                  Text(rs(monthly), style: t.h3),
                  Text('per month · 3 · no advance', style: t.tiny),
                  Text('Cash price ${rs(price)}', style: t.tiny),
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
