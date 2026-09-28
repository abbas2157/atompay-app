import 'dart:async';

import 'package:flutter/material.dart';

/// Rebuilds every second until [until], passing the seconds left (0 = done).
/// Used for resend timers and `429` countdowns.
class CountdownBuilder extends StatefulWidget {
  const new({required this.until, required this.builder, super.key});

  final DateTime? until;
  final Widget Function(BuildContext context, int secondsLeft) builder;

  @override
  State<CountdownBuilder> createState() => _CountdownBuilderState();
}

class _CountdownBuilderState extends State<CountdownBuilder> {
  Timer? _timer;

  int get _left {
    final until = widget.until;
    if (until == null) return 0;
    final ms = until.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(CountdownBuilder old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_left == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}
