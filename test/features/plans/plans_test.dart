import 'dart:async';

import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/features/plans/presentation/plan_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

Map<String, Object?> _instalment(
  int id,
  String state, {
  int amount = 19334,
  String due = '2026-10-05',
}) => {
  'id': id,
  'order_id': 1043,
  'label': 'Instalment ${id - 810}',
  'due_date': due,
  'amount': amount,
  'paid_amount': state == 'paid' ? amount : null,
  'paid_on': state == 'paid' ? '2026-08-04' : null,
  'state': state,
};

Map<String, Object?> _plan({
  int id = 1043,
  String state = 'on_track',
  bool withProduct = true,
  bool withSchedule = false,
}) => {
  'order': {
    'id': id,
    'reference': 'AS-0$id',
    'status': 'Instalments',
    'status_label': 'Instalments',
    'ordered_at': '2026-07-02T10:15:00+00:00',
    'total_price': 140000,
    'advance': 24000,
    'financed': 116000,
    'tenure': 6,
  },
  'product': withProduct
      ? {
          'id': 47,
          'title': 'Poco C75 8GB RAM',
          'picture_url': null,
          'shop_url': 'https://atomshop.pk/product/poco-c75',
        }
      : null,
  'state': state,
  'progress': {
    'paid_count': 2,
    'total_count': 6,
    'paid_amount': 38666,
    'total_amount': 116000,
    'remaining_amount': 77334,
    'percent': 33,
  },
  'next_due': _instalment(813, 'due'),
  if (withSchedule)
    'instalments': [
      _instalment(811, 'paid', due: '2026-08-05'),
      _instalment(812, 'late', due: '2026-09-05'),
      _instalment(813, 'due'),
      _instalment(814, 'upcoming', due: '2026-11-05'),
    ],
};

FakeApi _api({List<Object?> active = const [], List<Object?> all = const []}) {
  return FakeApi()
    ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
    ..on('GET', '/dashboard', FakeReply(200, dashboardBody()))
    ..onCall(
      'GET',
      '/plans',
      (r) => FakeReply(200, {
        'data': r.queryParameters['include'] == 'completed' ? all : active,
      }),
    );
}

Future<void> _openPlansTab(WidgetTester tester) async {
  await tester.tap(find.text('Plans'));
  await settle(tester);
}

void main() {
  testWidgets('active tab lists plans with progress and next due', (
    tester,
  ) async {
    await pumpApp(tester, _api(active: [_plan()]), token: 't');
    await _openPlansTab(tester);

    expect(find.text('Poco C75 8GB RAM'), findsOneWidget);
    expect(find.text('AS-01043'), findsOneWidget);
    expect(find.text('PKR 38,666 of PKR 116,000 paid'), findsOneWidget);
    expect(find.text('Next: PKR 19,334 on 5 Oct 2026'), findsOneWidget);
    expect(find.text('Late'), findsNothing);
  });

  testWidgets('empty active tab points to AtomShop', (tester) async {
    await pumpApp(tester, _api(), token: 't');
    await _openPlansTab(tester);

    expect(
      find.text(
        'No instalment plans yet. Choose AtomPay at AtomShop checkout.',
      ),
      findsOneWidget,
    );
    expect(find.text('Shop on AtomShop.pk'), findsOneWidget);
  });

  testWidgets('history shows only completed plans', (tester) async {
    await pumpApp(
      tester,
      _api(
        active: [_plan()],
        all: [
          _plan(),
          _plan(id: 999, state: 'completed', withProduct: false),
        ],
      ),
      token: 't',
    );
    await _openPlansTab(tester);
    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.text('AS-0999'), findsOneWidget);
    expect(find.text('AS-01043'), findsNothing);
    // Product removed from AtomShop: placeholder wording, no crash.
    expect(find.text('Product no longer on AtomShop'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('detail shows totals and the full schedule by state', (
    tester,
  ) async {
    final api = _api(active: [_plan(state: 'late')])
      ..on(
        'GET',
        '/plans/1043',
        FakeReply(200, {'data': _plan(state: 'late', withSchedule: true)}),
      );
    await pumpApp(tester, api, token: 't');
    await _openPlansTab(tester);
    expect(find.text('Late'), findsOneWidget);

    await tester.ensureVisible(find.text('AS-01043'));
    await tester.pump();
    await tester.tap(find.text('AS-01043'));
    await settle(tester);
    expect(find.byType(PlanDetailScreen), findsOneWidget);
    await scrollTo(tester, find.text('6 months'));
    expect(find.text('PKR 140,000'), findsOneWidget);
    expect(find.text('PKR 24,000'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);

    await scrollTo(tester, find.text('Instalment 4'));
    expect(find.text('Paid 4 Aug 2026'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    await scrollTo(
      tester,
      find.text(
        "Pay through AtomShop's usual payment "
        'channels.',
      ),
    );
  });

  testWidgets('an unknown plan says "Plan not found"', (tester) async {
    final api = _api()
      ..on('GET', '/plans/5', const FakeReply(404, {'message': 'Not found'}));
    final container = await pumpApp(tester, api, token: 't');

    // Deep link, e.g. from a push notification.
    unawaited(container.read(routerProvider).push('/plans/5'));
    await settle(tester);

    expect(find.text('Plan not found.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('dashboard next-due card opens the plan', (tester) async {
    final api = _api()
      ..on(
        'GET',
        '/dashboard',
        FakeReply(
          200,
          dashboardBody(
            nextDue: {..._instalment(813, 'due'), 'order_id': 1043},
          ),
        ),
      )
      ..on(
        'GET',
        '/plans/1043',
        FakeReply(200, {'data': _plan(withSchedule: true)}),
      );
    await pumpApp(tester, api, token: 't');

    await scrollTo(tester, find.text('NEXT INSTALMENT'));
    await tester.tap(find.text('NEXT INSTALMENT'));
    await settle(tester);

    expect(find.byType(PlanDetailScreen), findsOneWidget);
  });
}
