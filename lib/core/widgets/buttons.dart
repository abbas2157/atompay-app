import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Nucleus pill, full width. While [loading] it shows a spinner, keeps its
/// width and ignores taps (no double submits, handbook rule 25).
class PrimaryButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Base(
      label: label,
      loading: loading,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
        disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
      ),
      filled: true,
    );
  }
}

/// Transparent with a hairline border.
class GhostButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Base(
      label: label,
      loading: loading,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.line),
      ),
    );
  }
}

/// Coral label and border. Always confirm before the action runs.
class DestructiveButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _Base(
      label: label,
      loading: loading,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.coral,
        side: const BorderSide(color: AppColors.coral),
      ),
    );
  }
}

class _Base extends StatelessWidget {
  const new({
    required this.label,
    required this.loading,
    required this.onPressed,
    required this.style,
    this.filled = false,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final ButtonStyle style;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shaped = style.merge(
      ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, Sizes.buttonHeight),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: WidgetStatePropertyAll(context.text.label),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Space.x24),
        ),
      ),
    );
    final child = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.tokens.ink,
            ),
          )
        : Text(label, textAlign: TextAlign.center);
    final onTap = loading ? null : onPressed;
    return Semantics(
      button: true,
      label: loading ? label : null,
      child: filled
          ? FilledButton(onPressed: onTap, style: shaped, child: child)
          : OutlinedButton(onPressed: onTap, style: shaped, child: child),
    );
  }
}
