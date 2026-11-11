@Tags(['golden'])
library;

import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/presentation/onboarding_screen.dart';
import 'package:atompay_mobile/features/notifications/application/inbox_controller.dart';
import 'package:atompay_mobile/features/notifications/presentation/notif_permission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// One golden image per canvas board (brief §15), named after the board's
/// file in docs/design/canvas. The reference boards that show UI get
/// images too: Style guide is the widget gallery; States and Navigation are
/// split into the app's real cases (`States-*`, `Navigation-*`). The table
/// boards (Architecture, Compliance, Main) are checked as data by
/// test/release/canvas_docs_test.dart.
final _now = DateTime(2026, 11, 9, 10);
const _phone = Size(390, 844);
const _tablet = Size(1024, 1366);

class _Camera implements CameraService {
  new(this.permission);

  final CamPermission permission;

  @override
  Future<CamPermission> status() async => permission;
  @override
  Future<CamPermission> request() async => permission;
  @override
  Future<void> openSettings() async {}
  @override
  Future<CameraSession> open({required bool front}) async =>
      _Session(front: front);
}

class _Session implements CameraSession {
  new({required this.front});

  final bool front;

  @override
  bool get hasFlash => !front;
  @override
  Widget preview() => const ColoredBox(color: Color(0xFF1C2740));
  @override
  Future<void> setFlash({required bool on}) async {}
  @override
  Future<Uint8List> take() async => Uint8List(0);
  @override
  Future<void> dispose() async {}
}

class FakeVoice implements VoiceInput {
  new(this.permission);

  final MicPermission permission;
  void Function(String text, {required bool done})? onText;

  @override
  Future<MicPermission> status() async => permission;
  @override
  Future<MicPermission> request() async => permission;
  @override
  Future<bool> start({
    required void Function(String text, {required bool done}) onText,
    required VoidCallback onStopped,
  }) async {
    this.onText = onText;
    return true;
  }

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

/// How to reach a board.
class Board {
  const new(
    this.name, {
    this.route,
    this.scenario = FakeScenario.repaying,
    this.signedIn = true,
    this.consented = true,
    this.onboarded = true,
    this.size = _phone,
    this.before,
    this.prepare,
    this.act,
    this.camera = CamPermission.granted,
    this.mic = MicPermission.granted,
    this.online = true,
  });

  final String name;

  /// Null stays wherever launch lands.
  final String? route;
  final FakeScenario scenario;
  final bool signedIn;
  final bool consented;

  /// False: a fresh install, on the intro slides.
  final bool onboarded;
  final Size size;

  /// Before launch (app-config knobs).
  final void Function(FakeServer s)? before;

  /// After launch, before going to [route] (failures, hangs).
  final void Function(Harness h)? prepare;

  /// After arriving (open a sheet, submit a form).
  final Future<void> Function(WidgetTester t, Harness h, FakeVoice v)? act;
  final CamPermission camera;
  final MicPermission mic;

  /// What the phone reports about its connection.
  final bool online;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.last);
  await t.tap(f.last);
  await settle(t);
}

Future<void> _tapText(WidgetTester t, String text) => _tap(t, find.text(text));

Future<void> _openField(WidgetTester t, String label) =>
    _tap(t, find.bySemanticsLabel(RegExp('^${RegExp.escape(label)},')));

Future<void> _pick(WidgetTester t, String field, String option) async {
  await _openField(t, field);
  final sheet = find.byType(BottomSheet);
  await t.enterText(
    find.descendant(of: sheet, matching: find.byType(TextField)),
    option,
  );
  await settle(t);
  // The search box shows the same text; the row comes after it.
  await _tap(t, find.descendant(of: sheet, matching: find.text(option)));
  await _tapText(t, 'Use $option');
}

Future<void> _type(WidgetTester t, List<String> values) async {
  final fields = find.byType(TextField);
  for (var i = 0; i < values.length; i++) {
    await t.enterText(fields.at(i), values[i]);
  }
  await settle(t);
}

void _fail(Harness h, String path, ProviderOrFamily provider) {
  h.server.failNext[path] = 500;
  h.container.invalidate(provider);
}

void _hang(Harness h, String path, ProviderOrFamily provider) {
  h.server.hang.add(path);
  h.container.invalidate(provider);
}

final boards = <Board>[
  // Launch
  Board('Splash', before: (s) => s.hang.add('/app-config')),
  Board('UpdateRequired', before: (s) => s.minVersion = '9.0.0'),
  Board('Maintenance', before: (s) => s.maintenance = true),
  // Intro slides: not on the canvas (added on request), kept here so a
  // change shows up in review.
  for (var i = 1; i <= onboardingSlides.length; i++)
    Board(
      'Onboarding-$i',
      consented: false,
      onboarded: false,
      signedIn: false,
      act: (t, _, _) async {
        // Decode the photos before the image is taken (async in tests).
        final context = t.element(find.byType(Scaffold).first);
        await t.runAsync(() async {
          for (final s in onboardingSlides) {
            if (s.photo != null) {
              await precacheImage(AssetImage(s.photo!), context);
            }
          }
        });
        await settle(t, frames: 3);
        for (var n = 1; n < i; n++) {
          await _tapText(t, 'Next');
        }
      },
    ),
  const Board('FirstRun', consented: false, signedIn: false),

  // Auth
  const Board('SignIn', route: '/login', signedIn: false),
  const Board('SignUp', route: '/register', signedIn: false),
  Board(
    'VerifyCode',
    route: '/register',
    signedIn: false,
    act: (t, h, _) async {
      await _type(t, [
        'Ayesha Khan',
        '0300 7013707',
        'password12',
        'password12',
      ]);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
    },
  ),
  const Board('ForgotPassword', route: '/forgot', signedIn: false),
  Board(
    'ForgotCode',
    route: '/forgot',
    signedIn: false,
    act: (t, h, _) async {
      await _type(t, ['ayesha@example.com']);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
    },
  ),
  Board(
    'NewPassword',
    route: '/forgot',
    signedIn: false,
    act: (t, h, _) async {
      await _type(t, ['ayesha@example.com']);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      await _type(t, [FakeServer.validCode]);
    },
  ),

  // Home
  const Board(
    'HomeNoLimit',
    route: '/home',
    scenario: FakeScenario.newCustomer,
  ),
  const Board('HomeApproved', route: '/home', scenario: FakeScenario.approved),
  const Board('HomeRepaying', route: '/home'),
  Board(
    'HomeLoading',
    route: '/home',
    prepare: (h) => _hang(h, '/dashboard', dashboardProvider),
  ),
  Board(
    'HomeError',
    route: '/home',
    prepare: (h) => _fail(h, '/dashboard', dashboardProvider),
  ),
  Board(
    'HomeOffline',
    route: '/home',
    prepare: (h) {
      h.server.offline.add('*');
      h.container.invalidate(dashboardProvider);
    },
  ),
  const Board('TabletHome', route: '/home', size: _tablet),
  const Board('Notifications', route: '/home/notifications'),
  Board(
    'NotificationsEmpty',
    route: '/home/notifications',
    before: (s) => s.notifications.clear(),
  ),
  Board(
    'NotificationsLoading',
    route: '/home/notifications',
    prepare: (h) => _hang(h, '/notifications', inboxControllerProvider),
  ),

  // Apply
  const Board(
    'ApplyPersonal',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
  ),
  const Board(
    'ApplyDocuments',
    route: '/application?step=2',
    scenario: FakeScenario.newCustomer,
  ),
  const Board(
    'ApplyIncome',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
  ),
  const Board(
    'ApplyReview',
    route: '/application?step=4',
    scenario: FakeScenario.newCustomer,
  ),
  Board(
    'CityPicker',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
    act: (t, h, _) => _openField(t, 'City'),
  ),
  Board(
    'PickerSheet',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
    act: (t, h, _) async {
      await _openField(t, 'City');
      await t.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'la',
      );
      await settle(t);
    },
  ),
  Board(
    'AreaPicker',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
    act: (t, h, _) async {
      await _pick(t, 'City', 'Lahore');
      await _openField(t, 'Area');
    },
  ),
  Board(
    'EmploymentPicker',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
    act: (t, h, _) => _openField(t, 'Employment status'),
  ),
  Board(
    'IncomePicker',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
    act: (t, h, _) => _openField(t, 'Income source'),
  ),
  const Board(
    'CameraPermission',
    route: '/application/capture/cnic_front',
    scenario: FakeScenario.newCustomer,
    camera: CamPermission.notAsked,
  ),
  const Board(
    'CaptureCnic',
    route: '/application/capture/cnic_front',
    scenario: FakeScenario.newCustomer,
  ),
  const Board(
    'CaptureSelfie',
    route: '/application/capture/selfie',
    scenario: FakeScenario.newCustomer,
  ),
  const Board('DocumentViewer', route: '/profile/document/cnic_front'),
  const Board('Verification', route: '/application/status'),
  Board(
    'AppReview',
    route: '/application/status',
    scenario: FakeScenario.approved,
    before: (s) => s.assessments.first
      ..['status'] = 'pending'
      ..['status_label'] = 'Pending',
  ),
  Board(
    'AppRejected',
    route: '/application/status',
    scenario: FakeScenario.approved,
    before: (s) => s.assessments.first
      ..['status'] = 'rejected'
      ..['status_label'] = 'Not approved',
  ),
  const Board('AppHistory', route: '/application/history'),

  // Shop
  const Board('Products', route: '/shop', scenario: FakeScenario.approved),
  Board(
    'ProductsEmpty',
    route: '/shop',
    act: (t, h, _) => _tapText(t, 'Fits my limit'),
  ),
  Board(
    'ProductsError',
    route: '/shop',
    prepare: (h) => h.server.failNext['/products'] = 500,
  ),
  Board(
    'ProductsLoading',
    route: '/shop',
    prepare: (h) => h.server.hang.add('/products'),
  ),
  const Board(
    'ProductPlan',
    route: '/shop/51',
    scenario: FakeScenario.approved,
  ),
  const Board('Calculator', route: '/calculator'),

  // Orders
  const Board('Plans', route: '/plans'),
  const Board('OrderStates', route: '/plans', scenario: FakeScenario.late),
  const Board('OrdersEmpty', route: '/plans', scenario: FakeScenario.approved),
  Board(
    'OrdersError',
    route: '/plans',
    prepare: (h) => _fail(h, '/plans', plansProvider),
  ),
  Board(
    'OrdersLoading',
    route: '/plans',
    prepare: (h) => _hang(h, '/plans', plansProvider),
  ),
  const Board('PlanDetail', route: '/plans/1279'),
  Board(
    'PlanDetailError',
    route: '/plans/1279',
    prepare: (h) => h.server.failNext['/plans/1279'] = 500,
  ),
  Board(
    'PlanDetailLoading',
    route: '/plans/1279',
    prepare: (h) => h.server.hang.add('/plans/1279'),
  ),
  const Board('PlanLate', route: '/plans/1279', scenario: FakeScenario.late),
  const Board('KeyFactStatement', route: '/plans/1279/kfs'),

  // Ask Atom
  const Board('AskAtom', route: '/atom'),
  Board(
    'AskAtomConvo',
    route: '/atom',
    act: (t, h, _) async {
      await _tapText(t, 'What does AtomPay cost?');
    },
  ),
  Board(
    'AskAtomVoice',
    route: '/atom',
    act: (t, h, v) async {
      await _tap(t, find.bySemanticsLabel('Ask by voice'));
      v.onText!('When is my next payment due', done: false);
      await settle(t);
    },
  ),
  Board(
    'AskAtomMic',
    route: '/atom',
    mic: MicPermission.notAsked,
    act: (t, h, _) => _tap(t, find.bySemanticsLabel('Ask by voice')),
  ),

  // Help
  const Board('HelpCentre', route: '/help'),
  const Board('HelpTopic', route: '/help/topic/buying?q=buy-directly'),
  const Board('Complaints', route: '/help/complaint'),
  Board(
    'TopicPicker',
    route: '/help/complaint',
    act: (t, h, _) => _openField(t, 'What is it about?'),
  ),
  Board(
    'OrderPicker',
    route: '/help/complaint',
    act: (t, h, _) => _openField(t, 'Which order? (optional)'),
  ),
  const Board('ComplaintSent', route: '/help/complaint/sent?ref=CMP-1042'),

  // Account
  const Board('Account', route: '/account'),
  const Board('Settings', route: '/account/settings'),
  Board(
    'SettingsSignOut',
    route: '/account/settings',
    act: (t, h, _) => _tapText(t, 'Sign out'),
  ),
  const Board('SecuritySettings', route: '/account/settings/security'),
  const Board('Permissions', route: '/account/settings/permissions'),
  const Board('NotifSettings', route: '/account/settings/notifications'),
  const Board('ChangePassword', route: '/account/settings/password'),
  const Board('Devices', route: '/account/devices'),
  const Board('DeleteAccount', route: '/account/delete'),
  Board(
    'DeleteBlocked',
    route: '/account/delete',
    act: (t, h, _) async {
      await _type(t, [FakeServer.validPassword]);
      await _tapText(
        t,
        'I understand this deletes my AtomPay and Atomshop.pk account.',
      );
      await _tapText(t, 'Delete my account');
    },
  ),
  const Board('AboutLegal', route: '/account/about'),
  const Board('Ecosystem', route: '/account/ecosystem'),
  const Board('RateUs', route: '/account/rate'),
  Board(
    'NotifPermission',
    route: '/home',
    act: (t, h, _) async {
      Navigator.of(rootNavigatorKey.currentContext!).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const NotifPermissionScreen(),
        ),
      );
      await settle(t);
    },
  ),

  // Reference: Style guide = the widget gallery, every component and state.
  const Board('StyleGuide', route: '/gallery', size: Size(390, 7200)),

  // Reference: States. Loading, empty, error and offline-with-cache are the
  // screen boards above (HomeLoading, OrdersEmpty, OrdersError, HomeOffline).
  Board(
    'States-401',
    route: '/home',
    act: (t, h, _) async {
      h.server.failNext['/dashboard'] = 401;
      h.container.invalidate(dashboardProvider);
      await settle(t);
    },
  ),
  Board(
    'States-429',
    route: '/account/settings/password',
    prepare: (h) => h.server.failNext['/me/password'] = 429,
    act: (t, h, _) async {
      await _type(t, [FakeServer.validPassword, 'newpass123', 'newpass123']);
      await _tap(t, find.widgetWithText(AppButton, 'Change password'));
    },
  ),
  Board(
    'States-Toast',
    route: '/account/settings/password',
    act: (t, h, _) async {
      await _type(t, [FakeServer.validPassword, 'newpass123', 'newpass123']);
      await _tap(t, find.widgetWithText(AppButton, 'Change password'));
    },
  ),
  const Board('States-OfflineSubmit', route: '/help/complaint', online: false),

  // Reference: Navigation.
  const Board('Navigation-TabRoot', route: '/shop'),
  const Board('Navigation-Pushed', route: '/shop/51'),
  const Board('Navigation-Rail', route: '/plans', size: _tablet),
  Board(
    'Navigation-Discard',
    route: '/account/settings/password',
    act: (t, h, _) async {
      await _type(t, ['typed']);
      await _tap(t, find.bySemanticsLabel('Back'));
    },
  ),
];

void main() {
  setUp(() => AppClock.pin(_now));
  tearDown(AppClock.reset);

  for (final b in boards) {
    testWidgets(b.name, (tester) async {
      tester.view
        ..physicalSize = b.size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final voice = FakeVoice(b.mic);
      final h = await Harness.create(
        scenario: b.scenario,
        consented: b.consented,
        onboarded: b.onboarded,
        token: b.signedIn ? 'token' : null,
        now: _now,
        setup: b.before,
        online: b.online,
        overrides: [
          cameraServiceProvider.overrideWithValue(_Camera(b.camera)),
          voiceInputProvider.overrideWithValue(voice),
          notificationPermissionProvider.overrideWithValue(_Notifications()),
        ],
      );
      addTearDown(h.dispose);
      await h.pumpApp(tester);
      b.prepare?.call(h);
      if (b.route != null) {
        h.container.read(routerProvider).go(b.route!);
        await settle(tester);
      }
      await b.act?.call(tester, h, voice);
      // Let the keyboard-free layout settle and shimmer land on one frame.
      await settle(tester, frames: 5);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('boards/${b.name}.png'),
      );
    });
  }
}
