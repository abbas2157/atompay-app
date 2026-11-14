import 'dart:convert';
import 'dart:typed_data';

import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/application/presentation/status_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

/// A 1×1 PNG: real image bytes, so review screens can decode them.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

class FakeCamera implements CameraService {
  new({this.permission = CamPermission.granted, this.grant = true});

  CamPermission permission;

  /// What the system prompt answers.
  bool grant;
  int opened = 0;
  int settingsOpened = 0;

  @override
  Future<CamPermission> status() async => permission;

  @override
  Future<CamPermission> request() async =>
      permission = grant ? CamPermission.granted : CamPermission.blocked;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<CameraSession> open({required bool front}) async {
    opened++;
    return _FakeSession(hasFlash: !front);
  }
}

class _FakeSession implements CameraSession {
  new({required this.hasFlash});

  @override
  final bool hasFlash;

  @override
  Widget preview() => const ColoredBox(color: Colors.black);

  @override
  Future<void> setFlash({required bool on}) async {}

  @override
  Future<Uint8List> take() async => Uint8List.fromList(_png);

  @override
  Future<void> dispose() async {}
}

String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

Future<Harness> start(
  WidgetTester tester, {
  FakeScenario scenario = FakeScenario.newCustomer,
  FakeCamera? camera,
  void Function(FakeServer server)? setup,
}) async {
  tester.view
    ..physicalSize = const Size(420, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(
    scenario: scenario,
    setup: setup,
    token: 'token',
    overrides: [
      cameraServiceProvider.overrideWithValue(camera ?? FakeCamera()),
    ],
  );
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  return h;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Taps a picker or date field by its accessible name ("City, Lahore").
Future<void> openField(WidgetTester tester, String label) async {
  final f = find.bySemanticsLabel(RegExp('^${RegExp.escape(label)},'));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> pick(WidgetTester tester, String field, String option) async {
  await openField(tester, field);
  final search = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );
  await tester.enterText(search, option);
  await settle(tester);
  await tester.tap(
    find
        .descendant(of: find.byType(BottomSheet), matching: find.text(option))
        // The search box shows the same text; the row comes after it.
        .last,
  );
  await settle(tester);
  await tester.tap(find.text('Use $option'));
  await settle(tester);
}

Future<void> fill(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await settle(tester, frames: 3);
}

Future<void> capture(WidgetTester tester, String row) async {
  await tapText(tester, row);
  await tester.tap(find.bySemanticsLabel(RegExp('Take (photo|selfie)')));
  await settle(tester);
  await tester.tap(find.text('Use photo'));
  await settle(tester);
}

void main() {
  testWidgets('a new customer applies end to end', (tester) async {
    final h = await start(tester);

    await tapText(tester, 'Apply for your limit');
    expect(location(h), Routes.applicationStep(1));
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Personal details'), findsWidgets);

    // Step 1. The name and mobile come pre-filled from AtomShop.
    await tapText(tester, 'Continue');
    expect(find.text('Enter the 13 digits of your CNIC.'), findsOneWidget);
    expect(find.text('Choose a city first'), findsOneWidget);

    await fill(tester, 'CNIC number', '4210198765432');
    expect(find.text('42101-9876543-2'), findsOneWidget);
    await openField(tester, 'Date of birth');
    await tester.tap(find.text('OK'));
    await settle(tester);
    await pick(tester, 'City', 'Lahore');
    await pick(tester, 'Area', 'Johar Town');
    await fill(tester, 'Residential address', 'House 14, Street 7, Block E');
    await tapText(tester, 'Continue');
    expect(location(h), Routes.applicationStep(2));

    // Step 2: camera only.
    await tapText(tester, 'Continue');
    expect(
      find.text('Take a photo of the front of your CNIC.'),
      findsOneWidget,
    );
    await capture(tester, 'CNIC front');
    await capture(tester, 'CNIC back');
    await capture(tester, 'Selfie with CNIC');
    expect(find.text('Taken · tap to retake'), findsNWidgets(3));
    await tapText(tester, 'Continue');
    expect(location(h), Routes.applicationStep(3));

    // Step 3, with the server's estimate.
    await pick(tester, 'Employment status', 'Salaried');
    await pick(tester, 'Income source', 'Salary');
    await fill(tester, 'Employer or business name', 'Cubic Reach (Pvt) Ltd');
    await fill(tester, 'Monthly income', '200000');
    expect(find.text('200,000'), findsOneWidget);
    await settle(tester, frames: 10);
    expect(find.text('Rs. 60,000'), findsOneWidget);
    expect(find.text('PROVISIONAL PURCHASE LIMIT'), findsOneWidget);
    await fill(tester, 'Household expenses', '80000');
    await tapText(tester, 'Continue');
    expect(location(h), Routes.applicationStep(4));

    // Step 4: nothing goes until the declaration is ticked.
    expect(find.text('Tick the declaration to submit'), findsOneWidget);
    expect(find.text('Lahore · Johar Town'), findsOneWidget);
    await tapText(
      tester,
      'I confirm these details are accurate and I '
      'authorise AtomPay to verify them, including a one-time visit to my '
      'residential address, for the purpose of setting my purchase limit.',
    );
    await tapText(tester, 'Submit application');

    expect(location(h), Routes.applicationStatus);
    expect(find.textContaining('Application received'), findsOneWidget);
    expect(h.server.assessments.last['monthly_income'], 200000);
    expect(h.server.profile!['area'], isNotNull);
    // Photos are gone from memory once sent.
    expect(h.container.read(applyFlowProvider).photos, isEmpty);

    // The wizard is gone: back goes Home.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await settle(tester);
    expect(location(h), Routes.home);
  });

  testWidgets('back keeps what was typed; leaving step 1 asks first', (
    tester,
  ) async {
    final h = await start(tester);
    h.container.read(routerProvider).go(Routes.home);
    await settle(tester);
    await tapText(tester, 'Apply for your limit');
    await fill(tester, 'Residential address', 'House 1');

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await settle(tester);
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(location(h), Routes.applicationStep(1));
    expect(find.text('House 1'), findsOneWidget);
  });

  testWidgets('changing the city clears the area', (tester) async {
    final h = await start(tester);
    h.container.read(routerProvider).go(Routes.applicationStep(1));
    await settle(tester);
    await pick(tester, 'City', 'Lahore');
    await pick(tester, 'Area', 'Johar Town');
    expect(find.text('Johar Town'), findsOneWidget);
    await pick(tester, 'City', 'Karachi');
    expect(find.text('Johar Town'), findsNothing);
    expect(h.container.read(applyFlowProvider).area, isNull);
  });

  testWidgets('camera: explainer first, then the system prompt', (
    tester,
  ) async {
    final camera = FakeCamera(permission: CamPermission.notAsked);
    final h = await start(
      tester,
      camera: camera,
      setup: (s) => s.seedDraftProfile(),
    );
    h.container.read(routerProvider).go(Routes.applicationStep(2));
    await settle(tester);
    await tapText(tester, 'CNIC front');
    expect(find.text('Photograph your CNIC'), findsOneWidget);
    expect(camera.opened, 0);
    await tapText(tester, 'Allow camera');
    expect(camera.opened, 1);
    expect(find.bySemanticsLabel('Take photo'), findsOneWidget);
  });

  testWidgets('camera: blocked goes to Settings', (tester) async {
    final camera = FakeCamera(permission: CamPermission.blocked);
    final h = await start(tester, camera: camera);
    h.container.read(routerProvider).go(Routes.capture(CaptureDoc.selfie.key));
    await settle(tester);
    expect(
      find.text('The camera is off for AtomPay\n', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('The camera is off for AtomPay', findRichText: true),
      findsOneWidget,
    );
    await tapText(tester, 'Open settings');
    expect(camera.settingsOpened, 1);
  });

  testWidgets('a limit review says so and 409 nothing_changed is shown', (
    tester,
  ) async {
    final h = await start(tester, scenario: FakeScenario.approved);
    h.container.read(routerProvider).go(Routes.applicationStep(3));
    await settle(tester);
    expect(find.text('Request a limit review'), findsOneWidget);
    await tapText(tester, 'Continue');
    await tapText(
      tester,
      'I confirm these details are accurate and I '
      'authorise AtomPay to verify them, including a one-time visit to my '
      'residential address, for the purpose of setting my purchase limit.',
    );
    await tapText(tester, 'Request limit review');
    expect(find.textContaining('nothing to review'), findsOneWidget);
    expect(location(h), Routes.applicationStep(4));
  });

  testWidgets('a pending review and its history', (tester) async {
    final h = await start(tester, scenario: FakeScenario.approved);
    h.server.assessments.add({
      ...h.server.assessments.last,
      'id': 939,
      'status': 'pending',
      'is_usable': false,
      'approved_limit': null,
      'max_instalment': null,
      'decided_at': null,
      'monthly_income': 260000,
    });
    h.container.read(routerProvider).go(Routes.applicationStatus);
    await settle(tester);
    expect(find.text('Limit review'), findsOneWidget);
    expect(
      find.textContaining('Rs. 60,000 limit stays active'),
      findsOneWidget,
    );
    expect(find.text('Application #939'), findsOneWidget);

    h.container.read(routerProvider).go(Routes.applicationHistory);
    await settle(tester);
    expect(find.text('Limit review'), findsOneWidget);
    expect(find.text('First application'), findsOneWidget);
    expect(find.textContaining('in force'), findsOneWidget);
    await tapText(tester, 'First application');
    expect(location(h), Routes.applicationDetail(311));
  });

  testWidgets('rejected: the reviewer note and what to do', (tester) async {
    final h = await start(tester);
    h.server.profile = {
      ...h.server.profile ?? {},
      'status': 'pending',
      'documents': const <String, dynamic>{},
    };
    h.server.assessments.add({
      'id': 401,
      'status': 'rejected',
      'is_usable': false,
      'monthly_income': 50000,
      'notes': 'Your expenses leave too little room for monthly payments.',
      'decided_at': DateTime(2026, 11).toIso8601String(),
    });
    h.container.read(routerProvider).go(Routes.applicationStatus);
    await settle(tester);
    expect(find.text("We couldn't approve a limit this time"), findsOneWidget);
    expect(
      find.text('Your expenses leave too little room for monthly payments.'),
      findsOneWidget,
    );
    expect(find.text('Raise a complaint'), findsOneWidget);
  });

  test('history kinds: first, review after a limit, plain application', () {
    Assessment a(int id, String status) =>
        Assessment(id: id, status: status, isUsable: status == 'approved');
    final list = [
      a(4, 'pending'),
      a(3, 'approved'),
      a(2, 'rejected'),
      a(1, 'rejected'),
    ];
    expect(kindOf(list, 0), 'Limit review');
    expect(kindOf(list, 1), 'Application');
    expect(kindOf(list, 3), 'First application');
  });
}
