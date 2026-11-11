import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/features/application/data/application_repository.dart';
import 'package:atompay_mobile/features/ask_atom/data/ask_atom_repository.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/help/data/complaints_repository.dart';
import 'package:atompay_mobile/features/home/data/dashboard_repository.dart';
import 'package:atompay_mobile/features/launch/data/config_repository.dart';
import 'package:atompay_mobile/features/notifications/data/notifications_repository.dart';
import 'package:atompay_mobile/features/plans/data/plans_repository.dart';
import 'package:atompay_mobile/features/shop/data/products_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Brief §15: every repository against the fake, which speaks the
/// documented contract (`docs/api`, brief §7.2). The same calls run against
/// a real server with the live contract tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Harness h;

  Future<void> signedIn([FakeScenario scenario = FakeScenario.repaying]) async {
    h = await Harness.create(scenario: scenario, token: 'token');
    addTearDown(h.dispose);
    // Launch loads the token into memory; these tests skip launch.
    await h.container.read(tokenStorageProvider).load();
  }

  group('ConfigRepository', () {
    test('app-config, options, cities, areas', () async {
      await signedIn();
      final r = h.container.read(configRepositoryProvider);
      final config = await r.appConfig();
      expect(config.features.voice, isTrue);
      expect(config.maintenance.active, isFalse);
      final options = await r.options();
      expect(options.employmentStatuses, isNotEmpty);
      expect(options.complaintTopics.map((t) => t.value), contains('payment'));
      final cities = await r.cities();
      expect(cities, isNotEmpty);
      expect(await r.areas(cities.first.id), isA<List<dynamic>>());
    });
  });

  group('AuthRepository', () {
    test('login: good and bad password', () async {
      h = await Harness.create();
      addTearDown(h.dispose);
      final r = h.container.read(authRepositoryProvider);
      await expectLater(
        r.login(login: 'ayesha@example.com', password: 'nope'),
        throwsA(isA<Validation>()),
      );
      final session = await r.login(
        login: 'ayesha@example.com',
        password: FakeServer.validPassword,
      );
      expect(session.token, isNotEmpty);
      expect(session.user.name, 'Ayesha Khan');
    });

    test('sign-up: register, resend, verify', () async {
      h = await Harness.create();
      addTearDown(h.dispose);
      final r = h.container.read(authRepositoryProvider);
      final sent = await r.register(
        name: 'Bilal Ahmed',
        login: 'bilal@example.com',
        password: 'password12',
        passwordConfirmation: 'password12',
      );
      expect(sent.id, isNotEmpty);
      expect((await r.resendSignupCode(sent.id)).id, isNotEmpty);
      final session = await r.verifySignup(
        signupId: sent.id,
        code: FakeServer.validCode,
      );
      expect(session.token, isNotEmpty);
    });

    test('reset: forgot, verify, reset', () async {
      h = await Harness.create();
      addTearDown(h.dispose);
      final r = h.container.read(authRepositoryProvider);
      final sent = await r.forgotPassword('ayesha@example.com');
      final token = await r.verifyResetCode(
        requestId: sent.id,
        code: FakeServer.validCode,
      );
      final session = await r.resetPassword(
        resetToken: token,
        password: 'newpass123',
        passwordConfirmation: 'newpass123',
      );
      expect(session.token, isNotEmpty);
    });

    test('me, sessions, preferences, password, logout', () async {
      await signedIn();
      final r = h.container.read(authRepositoryProvider);
      final (user, json) = await r.me();
      expect(user.kycStatus, json['kyc_status']);
      final sessions = await r.sessions();
      expect(sessions.where((s) => s.current), hasLength(1));
      await r.endSession(sessions.firstWhere((s) => !s.current).id);
      expect(await r.sessions(), hasLength(1));
      expect(await r.setEmailAlerts(on: false), isFalse);
      expect(await r.emailAlerts(), isFalse);
      await expectLater(
        r.changePassword(
          current: 'wrong',
          password: 'newpass123',
          passwordConfirmation: 'newpass123',
        ),
        throwsA(isA<Validation>()),
      );
      await r.changePassword(
        current: FakeServer.validPassword,
        password: 'newpass123',
        passwordConfirmation: 'newpass123',
      );
      await r.logout();
      expect(h.server.signedIn, isFalse);
    });

    test('delete: 409 while owing, 204 when clear', () async {
      await signedIn();
      final owing = h.container.read(authRepositoryProvider);
      await expectLater(
        owing.deleteAccount(FakeServer.validPassword),
        throwsA(
          isA<Conflict>().having((c) => c.code, 'code', 'outstanding_balance'),
        ),
      );
      h.dispose();
      await signedIn(FakeScenario.approved);
      await h.container
          .read(authRepositoryProvider)
          .deleteAccount(FakeServer.validPassword);
      expect(h.server.signedIn, isFalse);
    });

    test('logout-all signs this phone out too', () async {
      await signedIn();
      await h.container.read(authRepositoryProvider).logoutAll();
      expect(h.server.signedIn, isFalse);
    });
  });

  group('ApplicationRepository', () {
    test('profile, application, history, estimate', () async {
      await signedIn();
      final r = h.container.read(applicationRepositoryProvider);
      expect((await r.profile()).status, isNotEmpty);
      expect(await r.application(), isNotNull);
      expect(await r.history(), isNotEmpty);
      final e = await r.estimate(200000);
      expect(e.monthlyIncome, 200000);
      expect(e.estimatedLimit, greaterThan(0));
    });
  });

  group('DashboardRepository', () {
    test('dashboard, then the cached copy offline', () async {
      await signedIn();
      final r = h.container.read(dashboardRepositoryProvider);
      final live = await r.dashboard();
      expect(live.fromCache, isFalse);
      expect(live.data.limit.hasLimit, isTrue);
      h.server.offline.add('*');
      final cached = await r.dashboard();
      expect(cached.fromCache, isTrue);
      expect(cached.data.limit.approved, live.data.limit.approved);
    });

    test('offline with nothing cached is Offline', () async {
      await signedIn();
      h.server.offline.add('*');
      await expectLater(
        h.container.read(dashboardRepositoryProvider).dashboard(),
        throwsA(isA<Offline>()),
      );
    });
  });

  group('NotificationsRepository', () {
    test('inbox, mark one read, mark all read', () async {
      await signedIn();
      final r = h.container.read(notificationsRepositoryProvider);
      final inbox = (await r.inbox()).data;
      expect(inbox.items, isNotEmpty);
      await r.markRead(inbox.items.first.id);
      await r.markAllRead();
      expect((await r.inbox()).data.unreadCount, 0);
    });
  });

  group('PlansRepository', () {
    test('plans, plan, KFS, send KFS, 404', () async {
      await signedIn();
      final r = h.container.read(plansRepositoryProvider);
      final plans = (await r.plans()).data;
      expect(plans, isNotEmpty);
      final id = plans.first.order.id;
      expect((await r.plan(id)).instalments, isNotEmpty);
      final kfs = await r.kfs(id);
      expect(
        kfs.instalments.map((i) => i.amount).fold(0, (a, b) => a + b),
        kfs.totalRepayable,
      );
      await r.sendKfs(id, 'email');
      await expectLater(r.plan(999999), throwsA(isA<NotFound>()));
    });
  });

  group('ProductsRepository', () {
    test('products, categories, product, plan preview', () async {
      await signedIn(FakeScenario.approved);
      final r = h.container.read(productsRepositoryProvider);
      final page = await r.products();
      expect(page.items, isNotEmpty);
      expect(await r.categories(), isNotEmpty);
      expect((await r.product(page.items.first.id)).title, isNotEmpty);
      final preview = await r.planPreview(47000);
      expect(preview.instalments, [15666, 15666, 15668]);
      expect(preview.processingFee, 1410);
    });
  });

  group('AskAtomRepository', () {
    test('chips, ask, 422 on empty', () async {
      await signedIn();
      final r = h.container.read(askAtomRepositoryProvider);
      expect(await r.chips(), isNotEmpty);
      final a = await r.ask('What does AtomPay cost?');
      expect(a.paragraphs, isNotEmpty);
      expect(a.table, isNotNull);
      await expectLater(r.ask(''), throwsA(isA<Validation>()));
    });
  });

  group('ComplaintsRepository', () {
    test('send, 422 when too short', () async {
      await signedIn();
      final r = h.container.read(complaintsRepositoryProvider);
      final receipt = await r.send(
        topic: 'payment',
        message: 'My payment was taken twice.',
      );
      expect(receipt.reference, startsWith('CMP-'));
      await expectLater(
        r.send(topic: 'payment', message: 'short'),
        throwsA(isA<Validation>()),
      );
    });

    test('a 429 carries Retry-After', () async {
      await signedIn();
      h.server.failNext['/complaints'] = 429;
      await expectLater(
        h.container
            .read(complaintsRepositoryProvider)
            .send(topic: 'payment', message: 'My payment was taken twice.'),
        throwsA(isA<RateLimited>()),
      );
    });
  });
}
