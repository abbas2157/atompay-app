import 'package:atompay_mobile/features/application/presentation/application_form_screen.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

/// The 7 banner situations from handbook §8.8, with where the CTA leads.
const _banners = [
  ('pending', 'Start your AtomPay application', 'Apply now', 'apply'),
  ('blocked', 'Application not approved', 'Re-apply', 'application'),
  ('blocked', 'Verification unsuccessful', 'Update details', 'profile'),
  ('done', 'Verification complete', 'Improve my limit', 'application'),
  ('pending', 'Tell us about your income', 'Add income', 'application'),
  ('pending', 'Address verification pending', 'Update details', 'profile'),
  ('pending', 'Risk assessment in progress', 'Update income', 'application'),
];

const _approvedLimit = {
  'has_limit': true,
  'status': 'approved',
  'approved': 60000,
  'used': 20000,
  'available': 40000,
  'used_percent': 33,
  'max_instalment': 20000,
  'tenure': 12,
};

FakeApi _api(Map<String, Object?> dashboard) => FakeApi()
  ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
  ..on('GET', '/dashboard', FakeReply(200, dashboard))
  ..on('GET', '/profile', const FakeReply(200, {'data': <String, Object?>{}}))
  ..on(
    'GET',
    '/application',
    const FakeReply(200, {
      'data': {
        'can_apply': true,
        'requires': null,
        'latest': null,
        'active': null,
      },
    }),
  )
  ..on(
    'GET',
    '/options',
    const FakeReply(200, {
      'data': {'employment_statuses': <Object>[], 'income_sources': <Object>[]},
    }),
  );

void main() {
  testWidgets('no limit yet: "Not set yet" and the 6-step stepper', (
    tester,
  ) async {
    await pumpApp(tester, _api(dashboardBody()), token: 't');

    expect(find.text('Hi, Ayesha K.'), findsOneWidget);
    expect(find.text('Start your AtomPay application'), findsOneWidget);
    expect(find.text('Not set yet'), findsOneWidget);
    expect(find.text('PKR 0'), findsNothing);

    await scrollTo(tester, find.text('Stage shop'));
    for (final key in ['kyc', 'address', 'income', 'risk', 'limit', 'shop']) {
      expect(find.text('Stage $key'), findsOneWidget);
    }
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Up next'), findsNWidgets(5));
  });

  testWidgets('approved limit shows what is left and the breakdown', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _api(
        dashboardBody(
          limit: _approvedLimit,
          applicationStatus: 'approved',
          nextDue: {
            'id': 812,
            'order_id': 1043,
            'label': '2nd Instalment',
            'due_date': '2026-10-05',
            'amount': 12500,
            'paid_amount': null,
            'paid_on': null,
            'state': 'due',
            'order_reference': 'AS-01043',
            'product_title': 'Poco C75 8GB RAM',
          },
        ),
      ),
      token: 't',
    );

    expect(find.text('PKR 40,000'), findsOneWidget);
    expect(find.text('PKR 60,000'), findsOneWidget);
    expect(find.text('PKR 20,000'), findsNWidgets(2)); // used, max instalment
    expect(find.text('12 months'), findsOneWidget);

    await scrollTo(tester, find.text('Monday, 5 October'));
    expect(find.text('PKR 12,500 · Poco C75 8GB RAM'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
  });

  for (final (tone, title, cta, action) in _banners) {
    testWidgets('banner "$title" routes "$action"', (tester) async {
      final api = _api(
        dashboardBody(
          banner: {
            'tone': tone,
            'title': title,
            'text': 'Server text for $title',
            'cta': cta,
            'action': action,
          },
        ),
      );
      await pumpApp(tester, api, token: 't');

      expect(find.text(title), findsOneWidget);
      expect(find.text('Server text for $title'), findsOneWidget);

      await tester.tap(find.text(cta));
      await settle(tester);

      if (action == 'application') {
        expect(find.byType(ApplicationFormScreen), findsOneWidget);
      } else {
        expect(find.byType(ProfileFormScreen), findsOneWidget);
      }
    });
  }

  testWidgets('a failed load offers a retry', (tester) async {
    final api = _api(dashboardBody())
      ..on('GET', '/dashboard', const FakeReply(500, {'message': 'boom'}));
    await pumpApp(tester, api, token: 't');

    expect(find.text('Something went wrong. Please try again.'), findsOne);
    expect(find.text('boom'), findsNothing);

    api.on('GET', '/dashboard', FakeReply(200, dashboardBody()));
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Start your AtomPay application'), findsOneWidget);
  });
}
