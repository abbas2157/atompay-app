import 'dart:async';

import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/security/app_lock.dart';
import 'package:atompay_mobile/features/guest/presentation/welcome_screen.dart';
import 'package:atompay_mobile/features/notifications/domain/inbox_controller.dart';
import 'package:atompay_mobile/features/notifications/presentation/inbox_screen.dart';
import 'package:atompay_mobile/features/plans/presentation/plan_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/harness.dart';

Map<String, Object?> _note(
  int id, {
  bool read = false,
  Map<String, Object?> payload = const {'screen': 'dashboard'},
}) => {
  'id': id,
  'type': 'instalment_due',
  'title': 'Notification $id',
  'body': 'Body $id',
  'payload': payload,
  'read': read,
  'created_at': '2026-10-02T04:00:00+00:00',
};

Map<String, Object?> _page(
  List<Map<String, Object?>> items, {
  required int page,
  required bool hasNext,
  int unread = 2,
}) => {
  'data': items,
  'links': {'next': hasNext ? '/notifications?page=${page + 1}' : null},
  'meta': {'current_page': page, 'unread_count': unread},
};

/// Always says yes; the real plugin isn't available in widget tests.
class _FakeBiometrics implements BiometricService {
  int prompts = 0;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return true;
  }

  @override
  Future<bool> isAvailable() async => true;

  // Unused members of the real class.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

FakeApi _signedInApi({int unread = 0}) {
  final dashboard = dashboardBody();
  (dashboard['data']! as Map)['unread_notifications'] = unread;
  return FakeApi()
    ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
    ..on('GET', '/dashboard', FakeReply(200, dashboard));
}

void main() {
  group('guest home', () {
    testWidgets('mirrors the website and keeps the tray on screen', (
      tester,
    ) async {
      await pumpApp(tester, FakeApi());

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        find.text('Shop on AtomShop. Pay for it in easy monthly steps.'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Pay monthly, keep the product'));
      await scrollTo(tester, find.text('Clear terms upfront'));
      await scrollTo(
        tester,
        find.text('Is every product on AtomShop eligible?'),
      );

      // The tray is visible wherever the visitor has scrolled to.
      expect(find.widgetWithText(OutlinedButton, 'Sign in'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create account'), findsOne);
    });

    testWidgets('the tray disappears once signed in', (tester) async {
      final container = await pumpApp(tester, _signedInApi(), token: 't');
      unawaited(container.read(routerProvider).push(Routes.calculator));
      await settle(tester);

      expect(find.widgetWithText(OutlinedButton, 'Sign in'), findsNothing);
    });
  });

  group('notifications inbox', () {
    test('payload routing (handbook §8.11)', () {
      expect(
        routeForPayload({'screen': 'plan', 'order_id': 1043}),
        '/plans/1043',
      );
      expect(routeForPayload({'screen': 'plan', 'order_id': '7'}), '/plans/7');
      expect(routeForPayload({'screen': 'profile'}), Routes.profile);
      expect(routeForPayload({'screen': 'dashboard'}), Routes.home);
      expect(routeForPayload({'screen': 'something_new'}), Routes.home);
      expect(routeForPayload({'screen': 'plan'}), Routes.home);
    });

    testWidgets('bell badge, list, tap opens the plan and marks it read', (
      tester,
    ) async {
      final api = _signedInApi(unread: 2)
        ..on(
          'GET',
          '/notifications',
          FakeReply(
            200,
            _page(
              [
                _note(57, payload: {'screen': 'plan', 'order_id': 1043}),
                _note(56, read: true),
              ],
              page: 1,
              hasNext: false,
            ),
          ),
        )
        ..on(
          'POST',
          '/notifications/57/read',
          FakeReply(200, {'data': _note(57, read: true)}),
        )
        ..on('GET', '/plans/1043', const FakeReply(404, {'message': 'x'}));
      await pumpApp(tester, api, token: 't');

      expect(find.text('2'), findsOneWidget); // badge
      await tester.tap(find.byTooltip('2 unread notifications'));
      await settle(tester);
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Notification 57'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);

      await tester.tap(find.text('Notification 57'));
      await settle(tester);
      expect(api.last('POST', '/notifications/57/read'), isNotNull);
      expect(find.byType(PlanDetailScreen), findsOneWidget);
    });

    testWidgets('loads the next page and marks all read', (tester) async {
      tester.view.physicalSize = const Size(1080, 1400);
      addTearDown(tester.view.reset);
      final api = _signedInApi(unread: 3)
        ..onCall(
          'GET',
          '/notifications',
          (r) => r.queryParameters['page'] == 2
              ? FakeReply(200, _page([_note(1)], page: 2, hasNext: false))
              : FakeReply(
                  200,
                  _page(
                    [for (var i = 40; i > 20; i--) _note(i)],
                    page: 1,
                    hasNext: true,
                  ),
                ),
        )
        ..on('POST', '/notifications/read-all', const FakeReply(204));
      final container = await pumpApp(tester, api, token: 't');
      unawaited(container.read(routerProvider).push(Routes.notifications));
      await settle(tester);

      await scrollTo(tester, find.text('Notification 1'), by: 600);
      expect(find.text('Notification 1'), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await settle(tester);
      expect(api.last('POST', '/notifications/read-all'), isNotNull);
      expect(find.text('Mark all as read'), findsNothing);
    });

    testWidgets('empty inbox', (tester) async {
      final api = _signedInApi()
        ..on(
          'GET',
          '/notifications',
          FakeReply(200, _page([], page: 1, hasNext: false, unread: 0)),
        );
      final container = await pumpApp(tester, api, token: 't');
      unawaited(container.read(routerProvider).push(Routes.notifications));
      await settle(tester);
      expect(find.text('No notifications yet.'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('Urdu lays the app out right-to-left', (tester) async {
      await pumpApp(tester, FakeApi(), settings: {'settings.locale': 'ur'});

      final context = tester.element(find.byType(WelcomeScreen));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(
        find.text(
          'AtomShop پر خریداری کریں۔ آسان ماہانہ قسطوں میں ادائیگی کریں۔',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'سائن اِن'), findsOneWidget);
    });

    testWidgets('dark theme applies app-wide', (tester) async {
      await pumpApp(tester, FakeApi(), settings: {'settings.theme': 'dark'});
      final context = tester.element(find.byType(WelcomeScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('changing language from the guest settings sheet', (
      tester,
    ) async {
      await pumpApp(tester, FakeApi());
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.tap(find.text('اردو'));
      await settle(tester);

      final context = tester.element(find.byType(WelcomeScreen));
      expect(Directionality.of(context), TextDirection.rtl);
    });
  });

  testWidgets('FLAG_SECURE follows the visible screen, not mounted ones', (
    tester,
  ) async {
    final calls = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('shop.atompay.app/secure'),
      (call) async {
        calls.add(call.arguments as bool);
        return null;
      },
    );
    final api = _signedInApi()
      ..on(
        'GET',
        '/profile',
        const FakeReply(200, {'data': <String, Object>{}}),
      )
      ..on('GET', '/plans', const FakeReply(200, {'data': <Object>[]}));
    await pumpApp(tester, api, token: 't');

    await tester.tap(find.text('Profile'));
    await settle(tester);
    expect(calls.last, isTrue);

    // Profile stays mounted in the background tab; the flag must drop.
    await tester.tap(find.text('Plans'));
    await settle(tester);
    expect(calls.last, isFalse);

    await tester.tap(find.text('Profile'));
    await settle(tester);
    expect(calls.last, isTrue);
  });

  group('biometric lock', () {
    testWidgets('covers a signed-in app until unlocked', (tester) async {
      final bio = _FakeBiometrics();
      await pumpApp(
        tester,
        _signedInApi(),
        token: 't',
        settings: {'settings.biometric': true},
        overrides: [biometricServiceProvider.overrideWithValue(bio)],
      );

      // The lock prompts on its own and the fake says yes.
      expect(bio.prompts, greaterThanOrEqualTo(1));
      expect(find.text('AtomPay is locked'), findsNothing);
      expect(find.text('Hi, Ayesha K.'), findsOneWidget);
    });

    testWidgets('stays locked when the prompt is refused', (tester) async {
      final bio = _RefusingBiometrics();
      await pumpApp(
        tester,
        _signedInApi(),
        token: 't',
        settings: {'settings.biometric': true},
        overrides: [biometricServiceProvider.overrideWithValue(bio)],
      );
      expect(find.text('AtomPay is locked'), findsOneWidget);
    });

    testWidgets('never shown to guests', (tester) async {
      await pumpApp(
        tester,
        FakeApi(),
        settings: {'settings.biometric': true},
        overrides: [
          biometricServiceProvider.overrideWithValue(_RefusingBiometrics()),
        ],
      );
      expect(find.text('AtomPay is locked'), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}

class _RefusingBiometrics implements BiometricService {
  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
