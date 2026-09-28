import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// Logo mark, one sentence, one action. Used for both empty and error states.
class MessageView extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AtomLogo(size: 56),
            const SizedBox(height: Space.x20),
            Text(
              message,
              style: context.text.body,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.x24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: GhostButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A `line2` block that pulses while content loads.
class Skeleton extends StatefulWidget {
  const new({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.5).animate(_pulse),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: t.line,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// A thin strip at the top of a screen: "You're offline…".
class OfflineStrip extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.amber.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.x8,
      ),
      child: Text(message, style: context.text.bodySmall),
    );
  }
}
