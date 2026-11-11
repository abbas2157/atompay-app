import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

class FakeCam implements CameraService {
  new(this.permission);

  final CamPermission permission;
  int settingsOpened = 0;

  @override
  Future<CamPermission> status() async => permission;

  @override
  Future<CamPermission> request() async => permission;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<CameraSession> open({required bool front}) =>
      throw UnimplementedError();
}

class _Notifications implements NotificationPermission {
  new(this.view);

  final PermissionView view;

  @override
  Future<PermissionView> status() async => view;

  @override
  Future<PermissionView> request() async => PermissionView.allowed;

  @override
  bool get dismissed => false;

  @override
  Future<void> dismiss() async {}
}

class _Voice implements VoiceInput {
  new(this.permission);

  final MicPermission permission;

  @override
  Future<MicPermission> status() async => permission;

  @override
  Future<MicPermission> request() async => permission;

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

String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

Future<Harness> at(
  WidgetTester tester,
  String route, {
  FakeScenario scenario = FakeScenario.repaying,
  FakeCam? camera,
}) async {
  tester.view
    ..physicalSize = const Size(420, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(
    scenario: scenario,
    token: 'token',
    overrides: [
      cameraServiceProvider.overrideWithValue(
        camera ?? FakeCam(CamPermission.granted),
      ),
      notificationPermissionProvider.overrideWithValue(
        _Notifications(PermissionView.notAsked),
      ),
      voiceInputProvider.overrideWithValue(_Voice(MicPermission.blocked)),
    ],
  );
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  h.container.read(routerProvider).go(route);
  await settle(tester);
  return h;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapLabel(WidgetTester tester, Pattern label) async {
  final f = find.bySemanticsLabel(label).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapButton(WidgetTester tester, String text) async {
  final f = find.widgetWithText(AppButton, text);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Opens each row from [from] and checks where it lands.
Future<void> expectRows(
  WidgetTester tester,
  Harness h,
  String from,
  Map<String, String> rows,
) async {
  for (final MapEntry(key: title, value: target) in rows.entries) {
    h.container.read(routerProvider).go(from);
    await settle(tester);
    await tapText(tester, title);
    expect(location(h), target, reason: '"$title" from $from');
  }
}

void main() {
  group('Account', () {
    testWidgets('profile, version, and every row lands right', (tester) async {
      final h = await at(tester, Routes.account);
      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.textContaining('0300 7013707'), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
      expect(find.textContaining('Earning more? Your Rs.'), findsOneWidget);

      await expectRows(tester, h, Routes.account, {
        'KYC & verification': Routes.applicationStatus,
        'My applications': Routes.applicationHistory,
        'Request a limit review': Routes.applicationStep(3),
        'Estimate a plan': Routes.calculator,
        'Settings': Routes.settings,
        'Help and Ask Atom': Routes.help,
        'Our ecosystem': Routes.ecosystem,
        'Raise a complaint': Routes.complaint,
        'Rate AtomPay': Routes.rate,
        'About, privacy and legal': Routes.about,
      });

      h.container.read(routerProvider).go(Routes.account);
      await settle(tester);
      await tapLabel(tester, 'Settings');
      expect(location(h), Routes.settings);
    });

    testWidgets('no limit: no limit review row', (tester) async {
      await at(tester, Routes.account, scenario: FakeScenario.newCustomer);
      expect(find.text('Request a limit review'), findsNothing);
    });
  });

  group('Settings', () {
    testWidgets('every row lands right; terms hidden while null', (
      tester,
    ) async {
      final h = await at(tester, Routes.settings);
      expect(find.text('Terms and conditions'), findsNothing);
      expect(find.text('2 devices signed in'), findsOneWidget);
      expect(find.text('AtomPay · Version 1.0.0 (1)'), findsOneWidget);

      await expectRows(tester, h, Routes.settings, {
        'Personal details': Routes.applicationStatus,
        'Notifications': Routes.notificationSettings,
        'Account security': Routes.security,
        'Change password': Routes.password,
        'Active sessions': Routes.devices,
        'Permissions': Routes.permissions,
        'Delete account': Routes.deleteAccount,
      });
      // "Ask through Help": one tappable paragraph.
      h.container.read(routerProvider).go(Routes.settings);
      await settle(tester);
      await tapLabel(tester, RegExp('^Need a copy of your data'));
      expect(location(h), Routes.help);
      await expectRows(tester, h, Routes.security, {
        'Password': Routes.password,
        'Signed-in devices': Routes.devices,
      });
    });

    testWidgets('sign out asks first, then goes to Sign in', (tester) async {
      final h = await at(tester, Routes.settings);
      await tapText(tester, 'Sign out');
      expect(find.text('Sign out of AtomPay?'), findsOneWidget);
      await tapText(tester, 'Stay signed in');
      expect(location(h), Routes.settings);

      await tapText(tester, 'Sign out');
      await tapText(tester, 'Sign out');
      expect(location(h), Routes.login);
      expect(h.server.signedIn, isFalse);
    });

    testWidgets('sign out everywhere goes to Sign in', (tester) async {
      final h = await at(tester, Routes.security);
      expect(find.text('Email on file · 0300 •••3707'), findsOneWidget);
      expect(find.text('This phone and 1 other'), findsOneWidget);
      await tapText(tester, 'Sign out everywhere');
      expect(find.text('Sign out everywhere?'), findsOneWidget);
      await tapText(tester, 'Sign out everywhere');
      expect(location(h), Routes.login);
      expect(h.server.signedIn, isFalse);
    });

    testWidgets('email alerts switch saves', (tester) async {
      final h = await at(tester, Routes.notificationSettings);
      expect(h.server.emailAlerts, isTrue);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(h.server.emailAlerts, isFalse);
    });

    testWidgets('permissions show live status and the never-asked list', (
      tester,
    ) async {
      final camera = FakeCam(CamPermission.granted);
      await at(tester, Routes.permissions, camera: camera);
      expect(find.bySemanticsLabel(RegExp('^Camera, Allowed')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Notifications, Not asked')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Microphone, Off')), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      await tapText(tester, 'Open phone settings');
      expect(camera.settingsOpened, 1);
    });
  });

  group('Change password', () {
    testWidgets('validates, shows server errors, then lands on Settings', (
      tester,
    ) async {
      final h = await at(tester, Routes.settings);
      await tapText(tester, 'Change password');
      final fields = find.byType(TextField);

      await tester.enterText(fields.at(0), 'wrong');
      await tester.enterText(fields.at(1), 'newpass123');
      await tester.enterText(fields.at(2), 'different1');
      await settle(tester);
      await tapButton(tester, 'Change password');
      expect(find.text("The passwords don't match."), findsOneWidget);

      await tester.enterText(fields.at(2), 'newpass123');
      await settle(tester);
      await tapButton(tester, 'Change password');
      expect(find.text("That password isn't right."), findsOneWidget);

      await tester.enterText(fields.at(0), FakeServer.validPassword);
      await settle(tester);
      await tapButton(tester, 'Change password');
      expect(h.server.password, 'newpass123');
      expect(location(h), Routes.settings);
      expect(
        find.text('Password changed. It works on AtomShop.pk too.'),
        findsOneWidget,
      );
    });

    testWidgets('a dirty form asks before leaving', (tester) async {
      final h = await at(tester, Routes.settings);
      await tapText(tester, 'Change password');
      await tester.enterText(find.byType(TextField).first, 'abc');
      await settle(tester);
      await tapLabel(tester, 'Back');
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tapText(tester, 'Discard');
      expect(location(h), Routes.settings);
    });
  });

  group('Devices', () {
    testWidgets('lists sessions and signs one out', (tester) async {
      final h = await at(tester, Routes.devices);
      expect(find.text('This phone'), findsOneWidget);
      expect(find.text('THIS DEVICE'), findsOneWidget);
      const other = 'Samsung Galaxy A54 · Android 14';
      expect(find.text(other), findsOneWidget);
      expect(find.textContaining('Last used'), findsOneWidget);

      await tapLabel(tester, 'Sign out $other');
      expect(find.text(other), findsNothing);
      expect(h.server.sessions, hasLength(1));
    });
  });

  group('Delete account', () {
    Future<void> confirm(WidgetTester tester, String password) async {
      await tester.enterText(find.byType(TextField), password);
      await settle(tester);
      await tapText(
        tester,
        'I understand this deletes my AtomPay and Atomshop.pk account.',
      );
      await tapText(tester, 'Delete my account');
    }

    testWidgets('a wrong password stays on the form', (tester) async {
      final h = await at(tester, Routes.deleteAccount);
      expect(
        find.widgetWithText(ElevatedButton, 'Delete my account'),
        findsNothing,
      );
      await confirm(tester, 'nope');
      expect(find.text("That password isn't right."), findsOneWidget);
      expect(location(h), Routes.deleteAccount);
    });

    testWidgets('409 outstanding balance: nothing deleted', (tester) async {
      final h = await at(tester, Routes.deleteAccount);
      await confirm(tester, FakeServer.validPassword);
      expect(find.text("You can delete once it's repaid"), findsOneWidget);
      expect(
        find.text('Your account is still open. Nothing has been deleted.'),
        findsOneWidget,
      );
      expect(find.textContaining('payments left'), findsOneWidget);
      expect(h.server.signedIn, isTrue);
      await tapText(tester, 'Back to account');
      expect(location(h), Routes.account);
    });

    testWidgets('deleted: Welcome, signed out', (tester) async {
      final h = await at(
        tester,
        Routes.deleteAccount,
        scenario: FakeScenario.approved,
      );
      await confirm(tester, FakeServer.validPassword);
      expect(location(h), Routes.welcome);
      expect(h.server.signedIn, isFalse);
    });
  });

  group('About, ecosystem, rate', () {
    testWidgets('About keeps the licence placeholders', (tester) async {
      final h = await at(tester, Routes.about);
      expect(find.text('[LICENSED ENTITY NAME]'), findsOneWidget);
      expect(find.text('SECP · [LICENCE NO.]'), findsOneWidget);
      expect(find.text('[REGISTERED ADDRESS]'), findsOneWidget);
      expect(find.text('Terms'), findsNothing);
      await tapText(tester, 'Key Fact Statements');
      expect(location(h), Routes.plans);
    });

    testWidgets('Ecosystem: missing store links say "soon"', (tester) async {
      await at(tester, Routes.ecosystem);
      expect(find.text('You are here'), findsOneWidget);
      expect(find.text('Android soon'), findsNWidgets(4));
      expect(find.text('iOS soon'), findsNWidgets(4));
      expect(find.text('Smart Seller'), findsOneWidget);
    });

    testWidgets('Rate AtomPay: honest ask; feedback goes to Help', (
      tester,
    ) async {
      final h = await at(tester, Routes.rate);
      expect(find.text('Rate on Google Play'), findsOneWidget);
      expect(find.text('Tell others what you think'), findsOneWidget);
      await tapText(tester, 'Send us feedback');
      expect(location(h), Routes.help);
    });
  });
}
