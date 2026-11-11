import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

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
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
