import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// Canvas auth `.content` (`padding-top:4px`): the gap between the page's
/// blocks. Sign in, sign up and the reset forms use 22; the code screens 24.
abstract final class AuthGap {
  static const form = SizedBox(height: Space.s22);
  static const code = SizedBox(height: Space.s24);

  /// `.form{gap:14px}` between fields.
  static const field = SizedBox(height: Space.s14);
}

/// The scrolling page of the auth screens: 16 dp gutters with the canvas's
/// 4 px top inset, width capped on tablets, and an optional [bottom] that
/// sits at the foot of the screen (`margin-top:auto; padding-bottom:28px`)
/// and scrolls with the content once it no longer fits.
class AuthPage extends StatelessWidget {
  const new({required this.children, this.bottom, super.key});

  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s4,
          Space.gutter,
          bottom == null ? Space.gutter : 0,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              minHeight: bottom == null
                  ? 0
                  : (box.maxHeight - Space.s4).clamp(0, double.infinity),
            ),
            // The footer sits at the foot of the screen, or after the
            // content once it no longer fits.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.s22,
                      bottom: Space.s28,
                    ),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "New to AtomPay? Create an account": centred `.small` text with an
/// 800-weight link of the same size.
class AuthFooterLink extends StatelessWidget {
  const new({
    required this.lead,
    required this.link,
    required this.onPressed,
    super.key,
  });

  final String lead;
  final String link;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(lead, style: t.small),
        TextLink(
          link,
          onPressed: onPressed,
          style: t.small.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// "Didn't get it? Resend in 0:42", then a Resend link once the server's
/// `resend_in` has passed.
class ResendRow extends StatefulWidget {
  const new({
    required this.sentAt,
    required this.resendIn,
    required this.onResend,
    this.waitingText = "Didn't get it? Resend in",
    this.actionText = 'Resend code',
    this.busy = false,
    super.key,
  });

  final DateTime? sentAt;
  final int resendIn;
  final VoidCallback onResend;
  final String waitingText;
  final String actionText;
  final bool busy;

  @override
  State<ResendRow> createState() => _ResendRowState();
}

class _ResendRowState extends State<ResendRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  @override
  void didUpdateWidget(ResendRow old) {
    super.didUpdateWidget(old);
    // A new code was sent: count down again.
    if (old.sentAt != widget.sentAt || old.resendIn != widget.resendIn) {
      _startTicking();
    }
  }

  /// Ticks once a second only while there is time left, so a finished
  /// countdown doesn't keep waking the phone.
  void _startTicking() {
    _tick?.cancel();
    _tick = null;
    if (_left == Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left == Duration.zero) {
        _tick?.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _left {
    final sent = widget.sentAt;
    if (sent == null) return Duration.zero;
    final left = sent
        .add(Duration(seconds: widget.resendIn))
        .difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final left = _left;
    if (left > Duration.zero) {
      return Center(
        child: Text.rich(
          TextSpan(
            style: t.small,
            children: [
              TextSpan(text: '${widget.waitingText} '),
              TextSpan(
                text: countdown(left),
                style: TextStyle(
                  color: context.colors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Center(
      child: TextLink(
        widget.actionText,
        onPressed: widget.busy ? null : widget.onResend,
      ),
    );
  }
}
