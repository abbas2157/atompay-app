import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// "No duplicates" (brief §5.4): a fast double tap opens a screen once, and
/// pushing the route already on top does nothing.
extension SafeNavigation on BuildContext {
  static bool _locked = false;

  /// Pushes [location] unless it is already on top or a push is under way.
  Future<T?> pushOnce<T extends Object?>(String location, {Object? extra}) {
    if (_locked) return Future.value();
    final router = GoRouter.of(this);
    // `state` is the top route, pushed ones included;
    // `currentConfiguration.uri` would only give the base location.
    final current = router.state.uri.toString();
    if (current == location) return Future.value();
    _locked = true;
    final result = router.push<T>(location, extra: extra);
    // Unlock once the new screen has had a frame to show.
    unawaited(
      SchedulerBinding.instance.endOfFrame.then(
        (_) =>
            SchedulerBinding.instance.endOfFrame.then((_) => _locked = false),
      ),
    );
    return result;
  }

  /// Visible for tests: whether a push is still settling.
  static bool get isLocked => _locked;

  @visibleForTesting
  static void unlock() => _locked = false;
}
