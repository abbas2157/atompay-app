import 'dart:async';

import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/notifications/data/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// FCM stand-in: a fixed token and streams the test drives.
class _FakePush implements PushMessaging {
  final opened$ = StreamController<Map<String, Object?>>.broadcast();
  final foreground$ = StreamController<PushMessage>.broadcast();
  final refresh$ = StreamController<String>.broadcast();
  String? current = 'token-1';
  int deleted = 0;

  @override
  bool get available => true;
  @override
  Future<void> start() async {}
  @override
  Future<String?> token() async => current;
  @override
  Stream<String> get tokenRefresh => refresh$.stream;
  @override
  Stream<PushMessage> get foreground => foreground$.stream;
  @override
  Stream<Map<String, Object?>> get opened => opened$.stream;
  @override
  Future<void> deleteToken() async => deleted++;
}

class _Allowed implements NotificationPermission {
  new(this.view);

  PermissionView view;

  @override
  Future<PermissionView> status() async => view;
  @override
  Future<PermissionView> request() async => view = PermissionView.allowed;
  @override
  bool get dismissed => true;
  @override
  Future<void> dismiss() async {}
}

Future<(Harness, _FakePush)> _start(
  WidgetTester tester, {
  bool serverPush = true,
  PermissionView permission = PermissionView.allowed,
}) async {
  final push = _FakePush();
  final h = await Harness.create(
    token: 'token',
    setup: (s) => s.pushEnabled = serverPush,
    overrides: [
      pushMessagingProvider.overrideWithValue(push),
      notificationPermissionProvider.overrideWithValue(_Allowed(permission)),
    ],
  );
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  return (h, push);
}

List<Map<String, dynamic>> _devices(Harness h, String method) => [
  for (final r in h.server.log)
    if (r.uri.path.endsWith('/devices') && r.method == method)
      (r.data as Map).cast<String, dynamic>(),
];

void main() {
  testWidgets('signed in and allowed: the phone registers its token', (
    tester,
  ) async {
    final (h, _) = await _start(tester);
    final posts = _devices(h, 'POST');
    expect(posts, isNotEmpty);
    expect(posts.last['fcm_token'], 'token-1');
    expect(posts.last['platform'], isNotEmpty);
    expect(posts.last['app_version'], isNotEmpty);
  });

  testWidgets('a new FCM token is registered again', (tester) async {
    final (h, push) = await _start(tester);
    push.refresh$.add('token-2');
    await settle(tester, frames: 5);
    expect(_devices(h, 'POST').last['fcm_token'], 'token-2');
  });

  testWidgets('not allowed, or push off on the server: nothing registers', (
    tester,
  ) async {
    final (h1, _) = await _start(tester, permission: PermissionView.off);
    expect(_devices(h1, 'POST'), isEmpty);
  });

  testWidgets('push off on the server: nothing registers', (tester) async {
    final (h, _) = await _start(tester, serverPush: false);
    expect(_devices(h, 'POST'), isEmpty);
  });

  testWidgets('a tapped push opens its screen', (tester) async {
    final (h, push) = await _start(tester);
    push.opened$.add({'screen': 'plan', 'order_id': '1279'});
    await settle(tester);
    expect(h.container.read(routerProvider).state.uri.path, Routes.plan(1279));
  });

  testWidgets('a push while open shows a toast and refreshes the inbox', (
    tester,
  ) async {
    final (h, push) = await _start(tester);
    final before = h.server.log
        .where((r) => r.uri.path.endsWith('/dashboard'))
        .length;
    push.foreground$.add(
      const PushMessage(
        title: 'Instalment due in 10 days',
        data: {'screen': 'plan', 'order_id': '1279'},
      ),
    );
    await settle(tester, frames: 5);
    expect(find.text('Instalment due in 10 days'), findsOneWidget);
    expect(
      h.server.log.where((r) => r.uri.path.endsWith('/dashboard')).length,
      greaterThan(before),
    );
  });

  testWidgets('signing out removes the token from the server', (tester) async {
    final (h, push) = await _start(tester);
    // Real async: the sign-out awaits the fake server's responses.
    await tester.runAsync(
      () => h.container.read(sessionProvider.notifier).signOut(),
    );
    await settle(tester);
    expect(_devices(h, 'DELETE').single['fcm_token'], 'token-1');
    expect(push.deleted, 1);
  });

  test('without Firebase values in the build, push is off', () {
    expect(FirebaseConfig.options, isNull);
    expect(PushSupport.ready, isFalse);
    expect(NoPushMessaging().available, isFalse);
  });
}
