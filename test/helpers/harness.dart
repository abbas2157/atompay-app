import 'package:atompay_mobile/app.dart';
import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

const testDevice = DeviceInfo(
  appVersion: '1.0.0',
  deviceName: 'Test Phone · Android 14',
  platform: 'android',
);

const userJson = {
  'id': 5012,
  'name': 'Ayesha Khan',
  'short_name': 'Ayesha K.',
  'email': 'ayesha@example.com',
  'email_verified': false,
  'phone': '03001234567',
  'phone_formatted': '0300 1234567',
  'member_since': '2026-09-24',
  'kyc_status': 'not_started',
};

const authBody = {
  'data': {
    'token': '20|atompay_test',
    'token_type': 'Bearer',
    'expires_at': '2026-10-24T06:47:14+00:00',
    'user': userJson,
  },
};

const appConfigBody = {
  'data': {
    'min_version': {'android': '1.0.0', 'ios': '1.0.0'},
    'store_url': {'android': null, 'ios': null},
    'shop_url': 'https://atomshop.pk',
    'password_reset_url': 'https://atompay.shop/forgot-password',
    'support': {'phone': null, 'whatsapp': null, 'email': null},
    'features': {
      'push': false,
      'password_reset_channels': ['email', 'whatsapp'],
      'signup_channels': ['email', 'whatsapp'],
    },
  },
};

/// A container wired to [api], with secure storage mocked. Pass [token] to
/// start with a stored session.
Future<ProviderContainer> makeContainer(
  FakeApi api, {
  String? token,
  Map<String, Object> settings = const {},
  List<Override> overrides = const [],
}) async {
  FlutterSecureStorage.setMockInitialValues({
    if (token != null) ...{
      'auth.token': token,
      'auth.expires_at': '2026-10-24T06:47:14.000Z',
    },
  });
  SharedPreferences.setMockInitialValues(settings);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      deviceInfoProvider.overrideWithValue(testDevice),
      sharedPrefsProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
  container.read(dioProvider).httpClientAdapter = api;
  addTearDown(container.dispose);
  return container;
}

/// Pumps the whole app and lets launch finish.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeApi api, {
  String? token,
  Map<String, Object> settings = const {},
  List<Override> overrides = const [],
}) async {
  api.on('GET', '/app-config', const FakeReply(200, appConfigBody));
  final container = await makeContainer(
    api,
    token: token,
    settings: settings,
    overrides: overrides,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AtomPayApp()),
  );
  await settle(tester);
  return container;
}

/// `pumpAndSettle` never settles while the splash orbit or a countdown
/// runs, so pump a fixed number of frames instead.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder fieldLabelled(String label) => find
    .ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column))
    .first;

/// Types into the TextField under the eyebrow [label].
Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.scrollUntilVisible(
    find.text(label.toUpperCase()),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  final field = find.descendant(
    of: fieldLabelled(label),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, text);
  await tester.pump();
}

/// A `/dashboard` body. Override parts with [banner], [limit] etc.
Map<String, Object?> dashboardBody({
  Map<String, Object?>? banner,
  Map<String, Object?>? limit,
  Map<String, Object?>? nextDue,
  String? applicationStatus,
  String kycStatus = 'not_started',
}) => {
  'data': {
    'kyc_status': kycStatus,
    'application_status': applicationStatus,
    'banner':
        banner ??
        {
          'tone': 'pending',
          'title': 'Start your AtomPay application',
          'text': 'Verify your identity and income to get a limit.',
          'cta': 'Apply now',
          'action': 'apply',
        },
    'limit':
        limit ??
        {
          'has_limit': false,
          'status': null,
          'approved': 0,
          'used': 0,
          'available': 0,
          'used_percent': 0,
          'max_instalment': 0,
          'tenure': null,
        },
    'stages': [
      for (final (i, key) in const [
        'kyc',
        'address',
        'income',
        'risk',
        'limit',
        'shop',
      ].indexed)
        {
          'key': key,
          'title': 'Stage $key',
          'hint': 'Hint $key',
          'state': i == 0 ? 'current' : 'upcoming',
        },
    ],
    'next_due': nextDue,
    'plans': {'active_count': 0, 'has_late': false},
    'unread_notifications': 0,
  },
};

/// Scrolls the screen's main list until [finder] is built and visible.
Future<void> scrollTo(WidgetTester tester, Finder finder, {double by = 200}) =>
    tester.scrollUntilVisible(
      finder,
      by,
      scrollable: find.byType(Scrollable).first,
    );

/// From the guest home, open sign-in via the bottom tray.
Future<void> goToSignIn(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Sign in'));
  await settle(tester);
}
