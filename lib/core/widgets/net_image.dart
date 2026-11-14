import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A product photo from Atomshop: kept on disk, so a second visit costs no
/// data, and decoded at the size it is shown, not the size it was uploaded
/// (a 2000 px photo in a 160 dp tile would otherwise hold ~16 MB).
class NetImage extends StatelessWidget {
  const new(
    this.url, {
    required this.fallback,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;

  /// While loading and when it fails.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        int? px(double logical) => logical.isFinite && logical > 0
            ? math.min((logical * ratio).round(), 2048)
            : null;
        final image = CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          memCacheWidth: px(box.maxWidth),
          fadeInDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        );
        if (semanticLabel == null) return ExcludeSemantics(child: image);
        return Semantics(label: semanticLabel, image: true, child: image);
      },
    );
  }
}
