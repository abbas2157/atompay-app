import 'dart:async';

import 'package:atompay_mobile/app.dart';
import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container wired to an in-memory [FakeServer]: no network, no
/// platform channels.
class Harness {
  new _(this.container, this.server, this.prefs);

  final ProviderContainer container;
  final FakeServer server;
  final SharedPreferences prefs;

  static Future<Harness> create({
    FakeScenario scenario = FakeScenario.repaying,
    bool consented = true,
    String? token,
    List<dynamic> overrides = const [],

    /// The fake server's "today" (golden tests pin it).
    DateTime? now,

    /// Adjusts the fake before the app starts (failures, hangs).
    void Function(FakeServer server)? setup,

    /// What the phone reports about its connection.
    bool online = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'app.installed': true,
      'consent.accepted_v1': consented,
    });
    FlutterSecureStorage.setMockInitialValues({'auth.token': ?token});
    final prefs = await SharedPreferences.getInstance();
    final server = FakeServer(
      scenario: scenario,
      latency: Duration.zero,
      now: now,
    );
    setup?.call(server);
    if (token != null) server.signedIn = true;
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        fakeServerProvider.overrideWithValue(server),
        dioProvider.overrideWith(
          (ref) => buildDio(
            tokens: ref.watch(tokenStorageProvider),
            events: ref.watch(apiEventsProvider),
            adapter: server,
            baseUrl: 'https://test.local/api/v1',
          ),
        ),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        ...overrides.cast(),
      ],
    );
    return Harness._(container, server, prefs);
  }

  /// Pumps the whole app and lets launch finish.
  Future<void> pumpApp(WidgetTester tester) async {
    SafeNavigation.unlock();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AtomPayApp(listenForLinks: false),
      ),
    );
    await settle(tester);
  }

  void dispose() => container.dispose();
}

/// `pumpAndSettle` with a cap: shimmer and countdowns never settle.
Future<void> settle(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

/// A [Dio] on the fake, for repository tests.
Dio fakeDio(FakeServer server, {String? token}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'))
    ..httpClientAdapter = server;
  if (token != null) dio.options.headers['Authorization'] = 'Bearer $token';
  return dio;
}

/// Swallows the unawaited futures some widgets start in tests.
void ignoreFuture(Future<void> f) => unawaited(f.catchError((_) {}));

/// Finds a widget by its semantics label.
Finder bySemantics(String label) => find.bySemanticsLabel(label);
