import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// One colour family per meaning, the same on every screen (handbook §4.2).
enum StatusTone {
  ok,
  pending,
  blocked,
  neutral,
  info;

  /// Maps any API status value. Unknown values fall back to [neutral].
  static StatusTone fromApi(String? value) => switch (value) {
    'paid' || 'verified' || 'approved' || 'done' => ok,
    'due' || 'pending' || 'conditional' => pending,
    'late' || 'rejected' || 'blocked' => blocked,
    'info' => info,
    _ => neutral,
  };

  Color color(AppTokens t) => switch (this) {
    ok => AppColors.ok,
    pending => AppColors.amber,
    blocked => AppColors.coral,
    info => AppColors.royal,
    neutral => t.muted,
  };
}

/// Coloured dot + label on a 10% tint. The label carries the meaning, the
/// colour only reinforces it.
class StatusPill extends StatelessWidget {
  const new({required this.label, required this.tone, super.key});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone.color(t);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x12,
        vertical: Space.x4 + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.x8),
          Flexible(
            child: Text(
              label,
              style: context.text.bodySmall.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width tinted message with an optional call to action (handbook §4.6).
class AppBanner extends StatelessWidget {
  const new({
    required this.tone,
    required this.title,
    super.key,
    this.text,
    this.cta,
    this.onCta,
  });

  final StatusTone tone;
  final String title;
  final String? text;
  final String? cta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final styles = context.text;
    final color = tone.color(t);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: styles.title),
          if (text != null && text!.isNotEmpty) ...[
            const SizedBox(height: Space.x4),
            Text(text!, style: styles.body),
          ],
          if (cta != null && onCta != null) ...[
            const SizedBox(height: Space.x12),
            FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size(Sizes.minTouch, Sizes.minTouch),
                textStyle: styles.label,
              ),
              child: Text(cta!),
            ),
          ],
        ],
      ),
    );
  }
}
