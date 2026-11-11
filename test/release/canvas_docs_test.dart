import 'dart:io';

import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// The canvas's table boards hold no UI of their own, so they are checked
/// as data: Main (every board is covered), Architecture (every screen's
/// route exists) and Compliance (every "where in the app" claim holds).
const _canvas = 'docs/design/canvas';
const _tableBoards = {'Main', 'Architecture', 'Compliance'};

/// Reference boards split into several images (test/goldens/boards_test).
const _splitBoards = {'States', 'Navigation'};

List<String> _boards() =>
    Directory(_canvas)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.dc.html'))
        .map((n) => n.replaceAll('.dc.html', ''))
        .toList()
      ..sort();

/// Paths on the Architecture board that the brief's route table renamed
/// (brief §1: the brief wins).
const _renamed = {
  '/account/notifications': Routes.notificationSettings,
  // Shorthand on the board for the sibling of /application/status.
  '/history': Routes.applicationHistory,
};

/// Sample values for path parameters.
String _sample(String path) => path
    .replaceAll(':orderId', '1279')
    .replaceAll(':productId', '51')
    .replaceAll(':id', '51')
    .replaceAll(':doc', 'cnic_front')
    .replaceAll('step=1..4', 'step=1');

/// No camera plugin in tests.
class _Camera implements CameraService {
  @override
  Future<CamPermission> status() async => CamPermission.notAsked;
  @override
  Future<CamPermission> request() async => CamPermission.notAsked;
  @override
  Future<void> openSettings() async {}
  @override
  Future<CameraSession> open({required bool front}) =>
      throw UnimplementedError();
}

void main() {
  group('Main: every board is covered', () {
    final goldens = Directory('test/goldens/boards');
    final images = goldens.existsSync()
        ? goldens
              .listSync()
              .map((f) => f.uri.pathSegments.last.replaceAll('.png', ''))
              .toSet()
        : <String>{};

    test('the canvas has boards', () => expect(_boards(), isNotEmpty));

    for (final board in _boards()) {
      if (_tableBoards.contains(board)) continue;
      test(board, () {
        final covered = _splitBoards.contains(board)
            ? images.any((i) => i.startsWith('$board-'))
            : images.contains(board);
        expect(
          covered,
          isTrue,
          reason:
              'No golden for $board. Add it to test/goldens/boards_test.dart '
              'and run `flutter test --tags golden --update-goldens`.',
        );
      });
    }
  });

  group('Architecture: every screen has its route', () {
    final html = File('$_canvas/Architecture.dc.html').readAsStringSync();
    final rows = RegExp(
      '<div><b>([^<]+)</b></div><div><code>([^<]+)</code></div>',
    ).allMatches(html).toList();

    test('the board lists screens', () => expect(rows.length, greaterThan(15)));

    for (final row in rows) {
      final screen = row.group(1)!;
      final paths = row
          .group(2)!
          .split('·')
          .map((p) => p.trim())
          .where((p) => p.startsWith('/'));
      for (final raw in paths) {
        final path = _renamed[raw] ?? raw;
        testWidgets('$screen: $raw', (tester) async {
          final h = await Harness.create(
            token: 'token',
            overrides: [cameraServiceProvider.overrideWithValue(_Camera())],
          );
          addTearDown(h.dispose);
          await h.pumpApp(tester);
          final target = Uri.parse(_sample(path));
          h.container.read(routerProvider).go(target.toString());
          await settle(tester);
          final landed = h.container.read(routerProvider).state.uri.path;
          if (Routes.public.contains(target.path)) {
            // Signed in, launch and auth screens are behind us: Home.
            expect(landed, Routes.home);
          } else {
            expect(landed, target.path, reason: '$raw is not a route');
            expect(find.text("That link isn't available"), findsNothing);
          }
        });
      }
    }
  });

  group('Compliance: every claim holds in the app', () {
    Future<Harness> at(
      WidgetTester tester,
      String route, {
      FakeScenario scenario = FakeScenario.repaying,
      bool signedIn = true,
      bool consented = true,
    }) async {
      tester.view
        ..physicalSize = const Size(390, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(
        scenario: scenario,
        token: signedIn ? 'token' : null,
        consented: consented,
      );
      addTearDown(h.dispose);
      await h.pumpApp(tester);
      h.container.read(routerProvider).go(route);
      await settle(tester);
      return h;
    }

    // Atomshop sells on instalments itself: the company is named, and no
    // SECP licence is claimed anywhere.
    const company = '[COMPANY NAME]';

    testWidgets('company shown on First run, no licence claimed', (
      tester,
    ) async {
      await at(tester, Routes.firstRun, signedIn: false, consented: false);
      expect(find.textContaining(company), findsWidgets);
      expect(find.textContaining('SECP'), findsNothing);
    });

    testWidgets('company shown on About, no licence claimed', (tester) async {
      await at(tester, Routes.about);
      expect(find.textContaining(company), findsWidgets);
      expect(find.textContaining('SECP'), findsNothing);
    });

    testWidgets('KFS: seller, APR, every instalment date (Apple 3.2.2)', (
      tester,
    ) async {
      await at(tester, Routes.kfs(1279));
      expect(find.textContaining(company), findsWidgets);
      expect(find.text('Annual percentage rate (APR)'), findsOneWidget);
      // "10 Dec 2026 · Rs. 15,666": one row per instalment.
      expect(find.textContaining(RegExp(r'\d{4} · Rs\. ')), findsNWidgets(3));
    });

    testWidgets('in-app grievance route', (tester) async {
      await at(tester, Routes.complaint);
      expect(find.text('Raise a complaint'), findsWidgets);
      expect(
        find.textContaining('A person reads every complaint'),
        findsOneWidget,
      );
    });

    testWidgets('in-app account deletion (Apple 5.1.1(v))', (tester) async {
      await at(tester, Routes.settings);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('no coercive recovery language on a late order', (
      tester,
    ) async {
      await at(tester, Routes.plan(1279), scenario: FakeScenario.late);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase())
          .join('\n');
      expect(texts, contains('talk to us'));
      for (final word in [
        'legal action',
        'penalty',
        'police',
        'defaulter',
        'recovery agent',
        'blacklist',
        'court',
      ]) {
        expect(texts, isNot(contains(word)), reason: word);
      }
    });

    test('no contacts, gallery, storage, location, phone or SMS', () {
      // Enforced on the merged manifest by tool/check_manifest.dart (CI)
      // and on the source manifest by release_rules_test.dart.
      final xml = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        RegExp(r'READ_EXTERNAL_STORAGE"\s+tools:node="remove"').hasMatch(xml),
        isTrue,
      );
    });
  });
}
