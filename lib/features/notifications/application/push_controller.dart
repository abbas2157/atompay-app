import 'dart:async';

import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/deep_links.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/notifications/application/inbox_controller.dart';
import 'package:atompay_mobile/features/notifications/data/push_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push on this phone (docs/api/notifications.md):
/// - registers the FCM token with `POST /devices` once signed in, allowed
///   and switched on by the server (`features.push`), and again whenever
///   FCM rotates it;
/// - `DELETE /devices` when signing out of this phone ([unregisterPush]);
/// - a tapped push opens its screen through the deep-link table;
/// - a push while the app is open shows a toast and refreshes the inbox.
class PushController {
  new(this._ref);

  final Ref _ref;
  final _subs = <StreamSubscription<Object?>>[];
  bool _started = false;

  PushMessaging get _push => _ref.read(pushMessagingProvider);

  /// Called once by the app. [open] navigates to a route.
  void start({required void Function(String route) open}) {
    if (_started || !_push.available) return;
    _started = true;
    unawaited(_push.start());
    _subs
      ..add(_push.opened.listen((data) => open(routeForPush(data))))
      ..add(_push.foreground.listen(_onForeground))
      ..add(_push.tokenRefresh.listen((t) => unawaited(_register(t))));
    _ref
      ..listen(sessionProvider, (previous, next) {
        if (next is SignedIn && previous is! SignedIn) {
          unawaited(syncRegistration());
        }
      })
      ..listen(appConfigProvider, (previous, next) {
        if (next.features.push && !(previous?.features.push ?? false)) {
          unawaited(syncRegistration());
        }
      });
    unawaited(syncRegistration());
  }

  /// Registers this phone when everything allows it. Safe to call often.
  Future<void> syncRegistration() async {
    if (!_push.available) return;
    if (_ref.read(sessionProvider) is! SignedIn) return;
    if (!_ref.read(appConfigProvider).features.push) return;
    final allowed = await _ref.read(notificationPermissionProvider).status();
    if (allowed != PermissionView.allowed) return;
    final token = await _push.token();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    if (_ref.read(sessionProvider) is! SignedIn) return;
    try {
      await _ref.read(deviceRegistryProvider).register(token);
    } on ApiException {
      // Tried again at the next sign-in, start or token refresh.
    }
  }

  void _onForeground(PushMessage m) {
    _ref
      ..invalidate(inboxControllerProvider)
      ..invalidate(dashboardProvider);
    final title = m.title;
    if (title != null && title.isNotEmpty) showToast(title);
  }

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}

final pushControllerProvider = Provider<PushController>((ref) {
  final c = PushController(ref);
  ref.onDispose(c.dispose);
  return c;
});
