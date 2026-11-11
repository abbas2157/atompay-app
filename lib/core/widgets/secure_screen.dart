import 'dart:async';

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wrap capture, document and Key Fact Statement screens (brief §12).
///
/// Android: sets `FLAG_SECURE` (no screenshots, blank recents preview) while
/// any secure screen is visible. Both platforms: covers the content while
/// the app is inactive, so the iOS app-switcher snapshot shows the mark.
class SecureScreen extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  static const _channel = MethodChannel('com.ecommerce.atompay/secure');
  static int _active = 0;

  static Future<void> _set({required bool secure}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // Widget tests and platforms without the channel.
    } on PlatformException {
      // Never crash a screen over this.
    }
  }

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _covered = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final cover = state != AppLifecycleState.resumed;
        if (cover != _covered && mounted) setState(() => _covered = cover);
      },
    );
  }

  /// Tab branches and routes under a pushed page stay mounted but hidden,
  /// with tickers off. Only a visible secure screen may hold the flag.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register(visible: TickerMode.valuesOf(context).enabled);
  }

  void _register({required bool visible}) {
    if (visible == _registered) return;
    _registered = visible;
    if (visible) {
      if (SecureScreen._active++ == 0) {
        unawaited(SecureScreen._set(secure: true));
      }
    } else if (--SecureScreen._active == 0) {
      unawaited(SecureScreen._set(secure: false));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _register(visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_covered)
        Positioned.fill(
          child: ColoredBox(
            color: context.colors.white,
            child: const Center(child: AtomPayMark(size: 64)),
          ),
        ),
    ],
  );
}
