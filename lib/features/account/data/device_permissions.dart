import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a permission reads on the Permissions screen.
enum PermissionView {
  allowed('Allowed'),
  off('Off'),
  notAsked('Not asked');

  new(this.label);

  final String label;

  static PermissionView camera(CamPermission p) => switch (p) {
    CamPermission.granted => allowed,
    CamPermission.notAsked => notAsked,
    CamPermission.denied || CamPermission.blocked => off,
  };

  static PermissionView mic(MicPermission p) => switch (p) {
    MicPermission.granted => allowed,
    MicPermission.notAsked => notAsked,
    MicPermission.denied || MicPermission.blocked => off,
  };
}

/// Notification permission (Android 13+ runtime, iOS). Asked only after
/// the NotifPermission explainer, which needs push to be live.
abstract class NotificationPermission {
  Future<PermissionView> status();

  /// Shows the system prompt (Android 13+, iOS). Only after the explainer.
  Future<PermissionView> request();

  /// "Not now" on the explainer: it is never shown again on its own.
  bool get dismissed;
  Future<void> dismiss();
}

/// Push needs FCM registration (`POST /devices` with a token), which isn't
/// built yet. Until it is, the explainer never shows, even when the server
/// sends `features.push: true`: asking for a permission the app can't use
/// would break both stores' rules.
abstract final class PushSupport {
  static const ready = false;
}

final notificationPermissionProvider = Provider<NotificationPermission>(
  (ref) => DeviceNotificationPermission(ref.watch(sharedPreferencesProvider)),
);

class DeviceNotificationPermission implements NotificationPermission {
  new(this._prefs);

  final SharedPreferences _prefs;

  /// Set by the explainer once it has shown the system prompt.
  static const askedKey = 'notifications.asked';
  static const dismissedKey = 'notifications.explainer_dismissed';

  @override
  Future<PermissionView> request() async {
    await _prefs.setBool(askedKey, true);
    final s = await Permission.notification.request();
    if (s.isGranted || s.isProvisional) return PermissionView.allowed;
    return PermissionView.off;
  }

  @override
  bool get dismissed => _prefs.getBool(dismissedKey) ?? false;

  @override
  Future<void> dismiss() => _prefs.setBool(dismissedKey, true);

  @override
  Future<PermissionView> status() async {
    final s = await Permission.notification.status;
    if (s.isGranted || s.isProvisional) return PermissionView.allowed;
    if (s.isPermanentlyDenied) return PermissionView.off;
    return (_prefs.getBool(askedKey) ?? false)
        ? PermissionView.off
        : PermissionView.notAsked;
  }
}

/// The three permissions AtomPay can use, read live.
@immutable
class PermissionsSnapshot {
  const new({
    required this.camera,
    required this.notifications,
    required this.microphone,
  });

  final PermissionView camera;
  final PermissionView notifications;
  final PermissionView microphone;
}

/// Read each time the screen shows and on return from phone settings.
final permissionsProvider = FutureProvider.autoDispose<PermissionsSnapshot>((
  ref,
) async {
  final camera = await ref.watch(cameraServiceProvider).status();
  final notifications = await ref
      .watch(notificationPermissionProvider)
      .status();
  final mic = await ref.watch(voiceInputProvider).status();
  return PermissionsSnapshot(
    camera: PermissionView.camera(camera),
    notifications: notifications,
    microphone: PermissionView.mic(mic),
  );
});
