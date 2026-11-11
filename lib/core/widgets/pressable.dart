import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The interaction states every control shares (brief §4): a 3 dp focus ring
/// with a 2 dp gap when focused from a keyboard or switch, a 98% scale while
/// pressed (off under reduced motion), a disabled state, and a 48 dp floor
/// on the hit area.
class Pressable extends StatefulWidget {
  const new({
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.pill)),
    this.semanticLabel,
    this.isButton = true,
    this.selected,
    this.scaleOnPress = true,
    this.focusRingColor,
    this.pressedColor,
    this.minSize = const Size(Sizes.target, Sizes.target),
    this.focusNode,
    this.autofocus = false,
    this.excludeChildSemantics = false,
    super.key,
  });

  final Widget child;

  /// Null disables the control.
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final bool isButton;
  final bool? selected;
  final bool scaleOnPress;

  /// White on the camera, primary everywhere else.
  final Color? focusRingColor;

  /// A wash painted over the child while pressed (rows, chips).
  final Color? pressedColor;
  final Size minSize;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = widget.scaleOnPress && _pressed && !context.reduceMotion
        ? 0.98
        : 1.0;
    final ringColor = widget.focusRingColor ?? c.primary;

    Widget body = AnimatedScale(
      scale: scale,
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 90),
      child: widget.pressedColor == null
          ? widget.child
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: _pressed ? widget.pressedColor : null,
              ),
              child: widget.child,
            ),
    );

    // The ring sits outside the control: 2 dp gap, then 3 dp of colour.
    body = Container(
      foregroundDecoration: _focused
          ? BoxDecoration(
              border: Border.all(
                color: ringColor,
                width: Sizes.focusRing,
                strokeAlign:
                    BorderSide.strokeAlignOutside + Sizes.focusGap / 1.5,
              ),
              borderRadius: widget.borderRadius,
            )
          : null,
      child: body,
    );

    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeChildSemantics,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minSize.width,
              minHeight: widget.minSize.height,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Gives a small control (a switch, a thumbs-up) an invisible 48 dp hit area
/// without changing how it looks.
class HitArea extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: Sizes.target,
      minHeight: Sizes.target,
    ),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}
