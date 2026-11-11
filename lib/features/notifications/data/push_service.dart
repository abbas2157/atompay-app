import 'dart:async';

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Firebase app AtomPay registers with, from the build's dart-defines
/// (`env/<flavor>.json`). Push stays off while any value is missing, so a
/// build without Firebase still works: the inbox and email carry
/// everything (docs/api/notifications.md).
///
/// The values come from the Firebase console, project settings, "Your
/// apps": the AtomPay Android and iOS apps in the project whose service
/// account the server sends with.
abstract final class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Null when this platform has no Firebase app configured.
  static FirebaseOptions? get options {
    if (kIsWeb || projectId.isEmpty || senderId.isEmpty) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android when androidAppId.isNotEmpty =>
        const FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      TargetPlatform.iOS when iosAppId.isNotEmpty => const FirebaseOptions(
        apiKey: iosApiKey,
        appId: iosAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: iosBundleId,
      ),
      _ => null,
    };
  }
}

/// A push that arrived while the app was open.
@immutable
class PushMessage {
  const new({required this.data, this.title, this.body});

  final String? title;
  final String? body;
  final Map<String, Object?> data;
}

/// The phone's push channel. Tests and unconfigured builds use
/// [NoPushMessaging].
abstract class PushMessaging {
  /// Whether push can work in this build at all.
  bool get available;

  /// Sets up the channel. Safe to call more than once.
  Future<void> start();

  /// The FCM token, or null when there is none (no permission yet, no
  /// Play services).
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Pushes that arrive while the app is in the foreground.
  Stream<PushMessage> get foreground;

  /// The `data` of a push the customer tapped, including the one that
  /// launched the app.
  Stream<Map<String, Object?>> get opened;

  /// Forgets the token (signing out of this phone).
  Future<void> deleteToken();
}

class NoPushMessaging implements PushMessaging {
  @override
  bool get available => false;
  @override
  Future<void> start() async {}
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get foreground => const Stream.empty();
  @override
  Stream<Map<String, Object?>> get opened => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}

class FirebasePushMessaging implements PushMessaging {
  new(this._options);

  final FirebaseOptions _options;
  Future<void>? _started;
  final _opened = StreamController<Map<String, Object?>>.broadcast();

  @override
  bool get available => true;

  @override
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
    final m = FirebaseMessaging.instance;
    // The OS shows the notification block itself in the background; in the
    // foreground the app shows a toast instead (brief §10).
    await m.setForegroundNotificationPresentationOptions();
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _opened.add(message.data),
    );
    final initial = await m.getInitialMessage();
    if (initial != null) {
      // After listeners attach to [opened].
      scheduleMicrotask(() => _opened.add(initial.data));
    }
  }

  @override
  Future<String?> token() async {
    await start();
    try {
      // The server sends to FCM registration tokens (`fcm_token`), not
      // to the installation ids of the newer register() API.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      // No Play services, no APNs token yet, or offline: try again later.
      return null;
    }
  }

  @override
  // Registration tokens, as above.
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushMessage> get foreground => FirebaseMessaging.onMessage.map(
    (m) => PushMessage(
      title: m.notification?.title,
      body: m.notification?.body,
      data: m.data,
    ),
  );

  @override
  Stream<Map<String, Object?>> get opened => _opened.stream;

  @override
  Future<void> deleteToken() async {
    await start();
    try {
      // Drops the registration token handed out above.
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } on Object {
      // Best effort: the server drops it on sign-out anyway.
    }
  }
}

final pushMessagingProvider = Provider<PushMessaging>((ref) {
  final options = FirebaseConfig.options;
  return options == null ? NoPushMessaging() : FirebasePushMessaging(options);
});

/// `POST /devices` and `DELETE /devices` (docs/api/notifications.md).
class DeviceRegistry {
  new(this._ref);

  final Ref _ref;

  Future<void> register(String token) => guard(() async {
    await _ref
        .read(dioProvider)
        .post<dynamic>(
          '/devices',
          data: {
            'fcm_token': token,
            'platform': platformKey,
            'app_version': _ref.read(packageInfoProvider).version,
          },
        );
  });

  Future<void> unregister(String token) => guard(() async {
    await _ref
        .read(dioProvider)
        .delete<dynamic>('/devices', data: {'fcm_token': token});
  });
}

final deviceRegistryProvider = Provider<DeviceRegistry>(DeviceRegistry.new);

/// Before signing out of this phone: the server stops pushing to it, and
/// FCM forgets the token. Best effort; the server also drops the phone's
/// registrations on logout.
Future<void> unregisterPush(Ref ref) async {
  final push = ref.read(pushMessagingProvider);
  if (!push.available) return;
  final token = await push.token();
  if (token != null) {
    try {
      await ref.read(deviceRegistryProvider).unregister(token);
    } on Object {
      // Signing out goes ahead.
    }
  }
  await push.deleteToken();
}
