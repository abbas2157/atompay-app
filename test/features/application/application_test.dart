import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/features/application/presentation/application_status_screen.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

const _options = {
  'data': {
    'employment_statuses': [
      {'value': 'salaried', 'label': 'Salaried', 'has_employer': true},
      {'value': 'freelancer', 'label': 'Freelancer', 'has_employer': false},
    ],
    'income_sources': [
      {'value': 'salary', 'label': 'Salary'},
      {'value': 'business', 'label': 'Business'},
    ],
  },
};

Map<String, Object?> _assessment({
  int id = 311,
  String status = 'pending',
  int? limit,
  String? notes,
}) => {
  'id': id,
  'status': status,
  'status_label': status,
  'is_usable': status == 'approved',
  'employment_status': 'salaried',
  'employment_status_label': 'Salaried',
  'employer_name': 'Acme Ltd',
  'income_source': 'salary',
  'income_source_label': 'Salary',
  'monthly_income': 200000,
  'existing_instalments': 10000,
  'monthly_expenses': 90000,
  'disposable_income': 100000,
  'approved_limit': limit,
  'max_instalment': limit == null ? null : 20000,
  'approved_tenure': limit == null ? null : 12,
  'notes': notes,
  'submitted_at': '2026-09-24T07:10:00+00:00',
  'decided_at': limit == null ? null : '2026-09-25T07:10:00+00:00',
};

FakeApi _api({
  bool canApply = true,
  Map<String, Object?>? latest,
  Map<String, Object?>? active,
}) => FakeApi()
  ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
  ..on(
    'GET',
    '/dashboard',
    FakeReply(
      200,
      dashboardBody(
        banner: {
          'tone': 'pending',
          'title': 'Tell us about your income',
          'text': null,
          'cta': 'Add income',
          'action': 'application',
        },
      ),
    ),
  )
  ..on('GET', '/options', const FakeReply(200, _options))
  ..on(
    'GET',
    '/application',
    FakeReply(200, {
      'data': {
        'can_apply': canApply,
        'requires': canApply ? null : 'profile',
        'latest': latest,
        'active': active,
      },
    }),
  );

Future<void> _openForm(WidgetTester tester, FakeApi api) async {
  await pumpApp(tester, api, token: 't');
  await tester.tap(find.text('Add income'));
  await settle(tester);
}

Future<void> _choose(WidgetTester tester, String option) async {
  // The first empty picker ("Choose") is the one to fill.
  await tester.tap(find.text('Choose').first);
  await settle(tester);
  await tester.tap(find.text(option).last);
  await settle(tester);
}

void main() {
  test('money formatter groups digits and parses back', () {
    TextEditingValue type(String t) => MoneyInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: t),
    );
    expect(type('200000').text, '200,000');
    expect(type('00123').text, '123');
    expect(type('12a3').text, '123');
    expect(type('1234567890123').text, '123,456,789');
    expect(MoneyInputFormatter.parse('200,000'), 200000);
    expect(MoneyInputFormatter.parse(''), isNull);
  });

  testWidgets('employer shows only when the status needs one; submits', (
    tester,
  ) async {
    final api = _api()
      ..on('POST', '/application', FakeReply(201, {'data': _assessment()}));
    await _openForm(tester, api);

    expect(find.text('EMPLOYER OR BUSINESS NAME'), findsNothing);
    await _choose(tester, 'Salaried');
    expect(find.text('EMPLOYER OR BUSINESS NAME'), findsOneWidget);

    await _choose(tester, 'Salary');
    await enterField(tester, 'Employer or business name', 'Acme Ltd');
    await enterField(tester, 'Monthly income', '200000');
    expect(find.text('200,000'), findsOneWidget);

    await scrollTo(tester, find.text('Submit application'));
    await tester.tap(find.text('Submit application'));
    await settle(tester);

    final body = api.last('POST', '/application')!.data as Map;
    expect(body, {
      'employment_status': 'salaried',
      'employer_name': 'Acme Ltd',
      'income_source': 'salary',
      'monthly_income': 200000,
      'existing_instalments': 0,
      'monthly_expenses': 0,
    });
    expect(find.byType(ApplicationStatusScreen), findsOneWidget);
  });

  testWidgets('client checks: required pickers and minimum income', (
    tester,
  ) async {
    final api = _api();
    await _openForm(tester, api);

    await enterField(tester, 'Monthly income', '500');
    await scrollTo(tester, find.text('Submit application'));
    await tester.tap(find.text('Submit application'));
    await settle(tester);

    expect(find.text('Enter at least PKR 1,000.'), findsOneWidget);
    expect(api.last('POST', '/application'), isNull);
  });

  testWidgets('409 profile_required sends the customer to the profile', (
    tester,
  ) async {
    final api = _api()
      ..on(
        'GET',
        '/profile',
        const FakeReply(200, {'data': <String, Object>{}}),
      )
      ..on(
        'POST',
        '/application',
        const FakeReply(409, {
          'message': 'Please complete your profile first.',
          'code': 'profile_required',
        }),
      );
    await _openForm(tester, api);
    await _choose(tester, 'Freelancer');
    await _choose(tester, 'Business');
    await enterField(tester, 'Monthly income', '80000');
    await scrollTo(tester, find.text('Submit application'));
    await tester.tap(find.text('Submit application'));
    await settle(tester);

    expect(find.byType(ProfileFormScreen), findsOneWidget);
  });

  testWidgets('can_apply false asks for identity first', (tester) async {
    await _openForm(tester, _api(canApply: false));
    expect(find.text('First, verify your identity'), findsOneWidget);
  });

  testWidgets('pre-fills from the latest application', (tester) async {
    await _openForm(tester, _api(latest: _assessment()));
    expect(find.text('Salaried'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('200,000'), findsOneWidget);
  });

  testWidgets('decided status shows limit and the staff note', (tester) async {
    final api =
        _api(
          latest: _assessment(
            status: 'conditional',
            limit: 45000,
            notes: 'Provide a salary slip.',
          ),
        )..on(
          'GET',
          '/dashboard',
          FakeReply(200, dashboardBody(applicationStatus: 'conditional')),
        );
    await pumpApp(tester, api, token: 't');

    await scrollTo(tester, find.text('Your application'));
    await tester.tap(find.text('Your application'));
    await settle(tester);

    expect(find.byType(ApplicationStatusScreen), findsOneWidget);
    expect(find.text('Approved with conditions'), findsOneWidget);
    await scrollTo(tester, find.text('Provide a salary slip.'));
    expect(find.text('PKR 45,000'), findsOneWidget);
    expect(find.text('12 months'), findsOneWidget);
  });

  group('with an approved limit the form is a limit review', () {
    final approved = _assessment(id: 300, status: 'approved', limit: 150000);
    const review = 'Request limit review';

    testWidgets('keeps the limit, blocks unchanged figures, then submits', (
      tester,
    ) async {
      final api = _api(latest: approved, active: approved)
        ..on('POST', '/application', FakeReply(201, {'data': _assessment()}));
      await _openForm(tester, api);

      expect(find.text('Request a limit review'), findsOneWidget);
      expect(
        find.text(
          'Your PKR 150,000 limit stays active while we review. '
          'You can keep shopping with it.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Change your income details to request a higher limit.'),
        findsOneWidget,
      );
      expect(find.text('Submit application'), findsNothing);

      // Same figures as on file: nothing to review yet.
      await scrollTo(tester, find.text(review));
      expect(
        find.text('Change your income details to request a review.'),
        findsOneWidget,
      );
      await tester.tap(find.text(review));
      await settle(tester);
      expect(api.last('POST', '/application'), isNull);

      await enterField(tester, 'Monthly income', '250000');
      expect(
        find.text('Change your income details to request a review.'),
        findsNothing,
      );
      await scrollTo(tester, find.text(review));
      await tester.tap(find.text(review));
      await settle(tester);

      expect(
        (api.last('POST', '/application')!.data as Map)['monthly_income'],
        250000,
      );
      expect(find.byType(ApplicationStatusScreen), findsOneWidget);
      expect(
        find.text(
          'Limit review requested. Your current limit stays active until '
          'our team decides.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('409 nothing_changed shows the message and stays', (
      tester,
    ) async {
      const message =
          'Nothing has changed since your limit was set. Update your income '
          'details to request a review.';
      final api = _api(latest: _assessment(), active: approved)
        ..on(
          'POST',
          '/application',
          const FakeReply(409, {'message': message, 'code': 'nothing_changed'}),
        );
      await _openForm(tester, api);

      // A review is already pending.
      expect(
        find.text(
          'A review is already with our team; submitting again updates it.',
        ),
        findsOneWidget,
      );
      await enterField(tester, 'Monthly income', '210000');
      await scrollTo(tester, find.text(review));
      await tester.tap(find.text(review));
      await settle(tester);

      expect(find.text(message), findsOneWidget);
      expect(find.byType(ApplicationStatusScreen), findsNothing);
      expect(find.text('Request a limit review'), findsOneWidget);
    });
  });

  testWidgets('estimator is public and labelled as an estimate', (
    tester,
  ) async {
    final api = FakeApi()
      ..on(
        'POST',
        '/estimate',
        const FakeReply(200, {
          'data': {
            'monthly_income': 150000,
            'estimated_limit': 45000,
            'estimated_max_instalment': 15000,
          },
        }),
      );
    await pumpApp(tester, api); // signed out

    // Guest home → "Estimate my limit".
    await scrollTo(tester, find.text('Estimate my limit'));
    await tester.ensureVisible(find.text('Estimate my limit'));
    await tester.pump();
    await tester.tap(find.text('Estimate my limit'));
    await settle(tester);
    await enterField(tester, 'Monthly income', '150000');
    await tester.tap(find.text('Estimate'));
    await settle(tester);

    expect(find.text('PKR 45,000'), findsOneWidget);
    expect(
      find.text('Estimate. Your real limit is decided after review.'),
      findsOneWidget,
    );
    expect(
      (api.last('POST', '/estimate')!.data as Map)['monthly_income'],
      150000,
    );
  });
}
