import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Brief §13: 48 dp targets, every control labelled, contrast pairs, and
/// text at 200% without clipping, on every screen a customer can reach.
class _Camera implements CameraService {
  @override
  Future<CamPermission> status() async => CamPermission.granted;
  @override
  Future<CamPermission> request() async => CamPermission.granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<CameraSession> open({required bool front}) =>
      throw UnimplementedError();
}

class _Voice implements VoiceInput {
  @override
  Future<MicPermission> status() async => MicPermission.granted;
  @override
  Future<MicPermission> request() async => MicPermission.granted;
  @override
  Future<bool> start({
    required void Function(String text, {required bool done}) onText,
    required VoidCallback onStopped,
  }) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

class _Notifications implements NotificationPermission {
  @override
  Future<PermissionView> status() async => PermissionView.notAsked;

  @override
  Future<PermissionView> request() async => PermissionView.allowed;

  @override
  bool get dismissed => false;

  @override
  Future<void> dismiss() async {}
}

const signedInRoutes = [
  Routes.home,
  Routes.notifications,
  Routes.shop,
  '/shop/51',
  Routes.calculator,
  Routes.plans,
  '/plans/1279',
  '/plans/1279/kfs',
  Routes.atom,
  Routes.account,
  Routes.settings,
  Routes.security,
  Routes.permissions,
  Routes.notificationSettings,
  Routes.password,
  Routes.devices,
  Routes.deleteAccount,
  Routes.about,
  Routes.ecosystem,
  Routes.rate,
  Routes.help,
  '/help/topic/buying?q=eligible',
  '/help/topic/all',
  Routes.complaint,
  '/help/complaint/sent?ref=CMP-1042',
  Routes.applicationStatus,
  Routes.applicationHistory,
];

const newCustomerRoutes = [
  Routes.home,
  '/application?step=1',
  '/application?step=2',
  '/application?step=3',
  '/application?step=4',
  Routes.plans,
];

const signedOutRoutes = [
  Routes.welcome,
  Routes.login,
  Routes.register,
  Routes.forgot,
];

Future<Harness> open(
  WidgetTester tester,
  String route, {
  FakeScenario scenario = FakeScenario.repaying,
  bool signedIn = true,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final h = await Harness.create(
    scenario: scenario,
    token: signedIn ? 'token' : null,
    overrides: [
      cameraServiceProvider.overrideWithValue(_Camera()),
      voiceInputProvider.overrideWithValue(_Voice()),
      notificationPermissionProvider.overrideWithValue(_Notifications()),
    ],
  );
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  h.container.read(routerProvider).go(route);
  await settle(tester);
  return h;
}

Future<void> meetsAll(WidgetTester tester, String route) async {
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: '$route: Android 48 dp targets',
  );
  await expectLater(
    tester,
    meetsGuideline(iOSTapTargetGuideline),
    reason: '$route: iOS 44 pt targets',
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: '$route: every control has a label',
  );
  await expectLater(
    tester,
    meetsGuideline(textContrastGuideline),
    reason: '$route: text contrast',
  );
}

void main() {
  group('guidelines (targets, labels, contrast)', () {
    for (final route in signedInRoutes) {
      testWidgets(route, (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, route);
        await meetsAll(tester, route);
        handle.dispose();
      });
    }
    for (final route in newCustomerRoutes) {
      testWidgets('new customer $route', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, route, scenario: FakeScenario.newCustomer);
        await meetsAll(tester, route);
        handle.dispose();
      });
    }
    for (final route in signedOutRoutes) {
      testWidgets('signed out $route', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, route, signedIn: false);
        await meetsAll(tester, route);
        handle.dispose();
      });
    }
  });

  // An overflow at 200% fails the test through FlutterError.
  group('text at 200%', () {
    for (final route in [
      ...signedInRoutes,
      ...signedOutRoutes,
      '/application?step=1',
    ]) {
      testWidgets(route, (tester) async {
        // Collect layout errors with their full diagnostics (which widget
        // overflowed), instead of the test failing on a bare message.
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previous);
        await open(
          tester,
          route,
          signedIn: !signedOutRoutes.contains(route),
          textScale: 2,
        );
        FlutterError.onError = previous;
        expect(
          errors,
          isEmpty,
          reason: errors.map((e) => e.toString()).join('\n\n'),
        );
      });
    }
  });
}
