@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/presentation/onboarding_screen.dart';
import 'package:atompay_mobile/features/notifications/presentation/notif_permission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> _type(WidgetTester t, List<String> values) async {
  final fields = find.byType(TextField);
  for (var i = 0; i < values.length; i++) {
    await t.enterText(fields.at(i), values[i]);
  }
  await settle(t);
}

/// Income answers as on the canvas (the identity part comes from
/// [FakeServer.seedDraftProfile]). The three photos are taken too: a later
/// step only opens once the earlier ones are done.
Future<void> _fillIncome(WidgetTester t, Harness h, {int step = 3}) async {
  h.container
      .read(applyFlowProvider.notifier)
      .update(
        (d) => d.copyWith(
          photos: {for (final doc in CaptureDoc.values) doc: Uint8List(0)},
          employment: 'salaried',
          employer: 'Cubic Reach (Pvt) Ltd',
          source: 'salary',
          income: 200000,
          existing: 0,
          expenses: 60000,
        ),
      );
  // The text fields read the draft when the step opens: open it again.
  final router = h.container.read(routerProvider);
  final here = Routes.applicationStep(step);
  router.go('/application?step=1');
  await settle(t);
  router.go(here);
  await settle(t);
}

final boards = <Board>[
  // Launch
  // The canvas "Splash" board is the signed-out Welcome screen.
  const Board('Splash', route: '/welcome', signedIn: false),
  Board('LaunchSplash', before: (s) => s.hang.add('/app-config')),
  Board(
    'UpdateRequired',
    before: (s) => s
      ..minVersion = '9.0.0'
      ..storeUrl =
          'https://play.google.com/store/apps/details?id=com.ecommerce.atompay',
  ),
  Board(
    'Maintenance',
    before: (s) => s
      ..maintenance = true
      ..maintenanceUntil = DateTime(2026, 11, 9, 16, 30).toIso8601String()
      ..support = {'phone': null, 'whatsapp': '+923001234567', 'email': null},
  ),
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
  // Set before launch, so the first load hangs or fails (an invalidate
  // after a good load keeps the old data on screen).
  Board('HomeLoading', route: '/home', before: (s) => s.hang.add('/dashboard')),
  Board(
    'HomeError',
    route: '/home',
    before: (s) => s.offline.add('/dashboard'),
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
    before: (s) => s.hang.add('/notifications'),
  ),

  // Apply
  Board(
    'ApplyPersonal',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
  ),
  Board(
    'ApplyDocuments',
    route: '/application?step=2',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
  ),
  Board(
    'ApplyIncome',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
    act: (t, h, _) => _fillIncome(t, h),
  ),
  Board(
    'ApplyReview',
    route: '/application?step=4',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
    act: (t, h, _) => _fillIncome(t, h, step: 4),
  ),
  Board(
    'CityPicker',
    route: '/application?step=1',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
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
    before: (s) => s.seedDraftProfile(),
    act: (t, h, _) => _openField(t, 'Area'),
  ),
  Board(
    'EmploymentPicker',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
    act: (t, h, _) async {
      await _fillIncome(t, h);
      await _openField(t, 'Employment status');
    },
  ),
  Board(
    'IncomePicker',
    route: '/application?step=3',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedDraftProfile(),
    act: (t, h, _) async {
      await _fillIncome(t, h);
      await _openField(t, 'Income source');
    },
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
  Board(
    'Verification',
    route: '/application/status',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedPendingApplication(),
  ),
  Board(
    'AppReview',
    route: '/application/status',
    scenario: FakeScenario.approved,
    // A review is a second, pending assessment while #311 stays in force.
    before: (s) => s.assessments.add({
      ...s.assessments.first,
      'id': 312,
      'status': 'pending',
      'status_label': 'Pending',
      'is_usable': false,
      'approved_limit': null,
      'max_instalment': null,
      'approved_tenure': null,
      'decided_at': null,
    }),
  ),
  Board(
    'AppRejected',
    route: '/application/status',
    scenario: FakeScenario.newCustomer,
    before: (s) => s.seedPendingApplication(rejected: true),
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
    before: (s) => s.timeout.add('/products'),
  ),
  Board(
    'ProductsLoading',
    route: '/shop',
    before: (s) => s.hang.add('/products'),
  ),
  const Board(
    'ProductPlan',
    route: '/shop/51',
    scenario: FakeScenario.approved,
  ),
  // Buy with AtomPay (docs/api/orders.md): on once the server takes orders.
  Board(
    'ProductBuy',
    route: '/shop/51',
    scenario: FakeScenario.approved,
    before: (s) => s.inAppOrders = true,
  ),
  Board(
    'CheckoutDelivery',
    route: '/shop/51/buy',
    scenario: FakeScenario.approved,
    before: (s) => s.inAppOrders = true,
  ),
  Board(
    'CheckoutReview',
    route: '/shop/51/buy',
    scenario: FakeScenario.approved,
    before: (s) => s.inAppOrders = true,
    act: (t, h, _) => _tapText(t, 'Continue'),
  ),
  Board(
    'OrderPlaced',
    route: '/shop/51/buy',
    scenario: FakeScenario.approved,
    before: (s) => s.inAppOrders = true,
    act: (t, h, _) async {
      await _tapText(t, 'Continue');
      await _tap(t, find.textContaining('I have read the Key Fact Statement'));
      await _tapText(t, 'Place order');
    },
  ),
  Board(
    'Calculator',
    route: '/calculator',
    act: (t, h, _) async {
      await t.enterText(find.byType(TextField).first, '47000');
      await settle(t);
    },
  ),

  // Orders
  const Board('Plans', route: '/plans'),
  Board(
    'OrderStates',
    route: '/plans',
    scenario: FakeScenario.approved,
    before: (s) => s.seedEveryOrderState(),
  ),
  const Board('OrdersEmpty', route: '/plans', scenario: FakeScenario.approved),
  Board(
    'OrdersError',
    route: '/plans',
    before: (s) => s.failNext['/plans'] = 500,
  ),
  Board('OrdersLoading', route: '/plans', before: (s) => s.hang.add('/plans')),
  const Board('PlanDetail', route: '/plans/1279'),
  Board(
    'PlanDetailError',
    route: '/plans/1279',
    // The canvas draws the not-found state.
    before: (s) => s.failNext['/plans/1279'] = 404,
  ),
  Board(
    'PlanDetailLoading',
    route: '/plans/1279',
    before: (s) => s.hang.add('/plans/1279'),
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

/// Phone boards render at the canvas board's full height, so the whole
/// design can be compared, not just the first screen of it.
final Map<String, double> _canvasHeights = () {
  final json = jsonDecode(
    File('docs/design/canvas/canvas.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final boards = json['boards'] as Map<String, dynamic>;
  return {
    for (final e in boards.entries)
      e.key.replaceAll('.dc.html', ''):
          ((e.value as Map<String, dynamic>)['h'] as num).toDouble(),
  };
}();

Size _sizeFor(Board b) {
  final h = _canvasHeights[b.name];
  if (b.size != _phone || h == null) return b.size;
  return Size(_phone.width, h);
}

void main() {
  setUp(() => AppClock.pin(_now));
  tearDown(AppClock.reset);

  for (final b in boards) {
    testWidgets(b.name, (tester) async {
      tester.view
        ..physicalSize = _sizeFor(b)
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
