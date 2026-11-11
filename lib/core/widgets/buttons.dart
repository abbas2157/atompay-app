import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:flutter/material.dart';

enum ButtonVariant { primary, dark, ghost, amber, danger }

/// Pill button, 48 high (54 when [large]). While [busy] the label becomes a
/// spinner in the label's colour and the width is kept; it is not dimmed.
class AppButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  });

  const new primary(
    this.label, {
    required this.onPressed,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  }) : variant = ButtonVariant.primary;

  const new ghost(
    this.label, {
    required this.onPressed,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  }) : variant = ButtonVariant.ghost;

  const new dark(
    this.label, {
    required this.onPressed,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  }) : variant = ButtonVariant.dark;

  const new danger(
    this.label, {
    required this.onPressed,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  }) : variant = ButtonVariant.danger;

  const new amber(
    this.label, {
    required this.onPressed,
    this.large = false,
    this.block = false,
    this.busy = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
    super.key,
  }) : variant = ButtonVariant.amber;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool large;
  final bool block;
  final bool busy;
  final IconData? icon;

  /// `Icons.north_east` marks a link that leaves the app.
  final IconData? trailingIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final disabled = onPressed == null && !busy;

    final (Color bg, Color fg, Color? border) = disabled
        ? (c.line, c.muted, null)
        : switch (variant) {
            ButtonVariant.primary => (c.primary, c.white, null),
            ButtonVariant.dark => (c.ink, c.white, null),
            ButtonVariant.ghost => (c.white, c.ink, c.line2),
            ButtonVariant.amber => (c.amber, c.ink, null),
            ButtonVariant.danger => (c.rose, c.white, null),
          };
    final style = (large ? t.buttonLarge : t.button).copyWith(color: fg);

    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: Space.s8),
        ],
        Flexible(
          child: Text(
            label,
            style: style,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: Space.s6),
          Icon(trailingIcon, size: 18, color: fg),
        ],
      ],
    );

    final content = busy
        ? Stack(
            alignment: Alignment.center,
            children: [
              // Keeps the width of the label.
              Visibility.maintain(visible: false, child: labelRow),
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              ),
            ],
          )
        : labelRow;

    return Semantics(
      label: busy ? '$label, in progress' : semanticLabel,
      excludeSemantics: busy || semanticLabel != null,
      child: Pressable(
        onTap: busy ? null : onPressed,
        child: _Fill(
          bg: bg,
          pressedBg: switch (variant) {
            ButtonVariant.primary => c.primaryDark,
            ButtonVariant.dark => c.ink3,
            ButtonVariant.ghost => c.surface2,
            ButtonVariant.amber => c.apayAmber,
            ButtonVariant.danger => c.danger,
          },
          border: border,
          minHeight: large ? Sizes.buttonLarge : Sizes.target,
          block: block,
          child: content,
        ),
      ),
    );
  }
}

class _Fill extends StatefulWidget {
  const new({
    required this.bg,
    required this.pressedBg,
    required this.border,
    required this.minHeight,
    required this.block,
    required this.child,
  });

  final Color bg;
  final Color pressedBg;
  final Color? border;
  final double minHeight;
  final bool block;
  final Widget child;

  @override
  State<_Fill> createState() => _FillState();
}

class _FillState extends State<_Fill> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: Container(
        constraints: BoxConstraints(
          minHeight: widget.minHeight,
          minWidth: widget.block ? double.infinity : 0,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s22,
          vertical: Space.s8,
        ),
        alignment: widget.block ? Alignment.center : null,
        decoration: BoxDecoration(
          color: _down ? widget.pressedBg : widget.bg,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: widget.border == null
              ? null
              : Border.all(color: widget.border!),
        ),
        child: widget.child,
      ),
    );
  }
}

/// A 48 dp round icon button. [label] is required: it is what TalkBack and
/// VoiceOver read.
class AppIconButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.background,
    this.size = 24,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: label,
        excludeChildSemantics: true,
        pressedColor: c.greySoft,
        child: Container(
          width: Sizes.target,
          height: Sizes.target,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(
            icon,
            size: size,
            color: onPressed == null ? c.glyph : (color ?? c.ink),
          ),
        ),
      ),
    );
  }
}

/// An inline text link (`Forgot password?`), with a 48 dp target.
class TextLink extends StatelessWidget {
  const new(
    this.label, {
    required this.onPressed,
    this.style,
    this.external = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;

  /// Leaves the app: adds ↗ and says so to screen readers.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s =
        style ??
        context.text.base.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w700,
        );
    return Pressable(
      onTap: onPressed,
      isButton: false,
      scaleOnPress: false,
      borderRadius: BorderRadius.circular(Radii.tile),
      semanticLabel: external ? '$label, opens outside the app' : label,
      excludeChildSemantics: true,
      minSize: const Size(0, Sizes.target),
      child: Semantics(
        link: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, style: s)),
              if (external) ...[
                const SizedBox(width: Space.s4),
                Icon(Icons.north_east, size: 16, color: s.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
