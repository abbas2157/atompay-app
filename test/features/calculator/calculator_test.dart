import 'dart:async';

import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

const _config = {
  'data': {
    'tenures': [3, 6, 12],
    'per_month_percentage': 3.5,
    'advance': {'min_ratio': 0.2, 'max_ratio': 0.6},
    'price': {'min': 10000, 'max': 300000, 'step': 5000},
  },
};

FakeReply _quote(RequestOptions r) {
  final body = r.data as Map;
  final price = body['price'] as int;
  final advance = body['advance'] as int;
  final months = body['months'] as int;
  return FakeReply(200, {
    'data': {
      'price': price,
      'advance': advance,
      'months': months,
      'per_month_percentage': 3.5,
      'financed': price - advance,
      'markup': 1000,
      'total': price + 1000,
      'monthly': 12345,
      'advance_bounds': {'min': price ~/ 5, 'max': price * 3 ~/ 5},
    },
  });
}

Future<FakeApi> _open(WidgetTester tester, {FakeApi? api}) async {
  final fake = (api ?? FakeApi())
    ..on('GET', '/calculator', const FakeReply(200, _config));
  final container = await pumpApp(tester, fake); // signed out: it's public
  unawaited(container.read(routerProvider).push('/calculator'));
  await settle(tester);
  return fake;
}

int _quoteCalls(FakeApi api) =>
    api.requests.where((r) => r.path == '/quote').length;

void main() {
  testWidgets('opens signed out, quotes with the default inputs', (
    tester,
  ) async {
    final api = FakeApi()..onCall('POST', '/quote', _quote);
    await _open(tester, api: api);

    expect(find.text('Plan calculator'), findsOneWidget);
    await scrollTo(
      tester,
      find.text(
        'Estimate. The exact figures are confirmed at AtomShop checkout.',
      ),
    );
    expect(find.text('PKR 12,345'), findsOneWidget);
    expect(
      find.text(
        'Estimate. The exact figures are confirmed at AtomShop checkout.',
      ),
      findsOneWidget,
    );
    final body = api.last('POST', '/quote')!.data as Map;
    expect(body['months'], 6);
    // Default price is snapped to the server's step; advance is 20%.
    expect((body['price'] as int) % 5000, 0);
    expect(body['advance'], (body['price'] as int) * 20 ~/ 100);
  });

  testWidgets('tenure chips come from the server; changes are debounced', (
    tester,
  ) async {
    final api = FakeApi()..onCall('POST', '/quote', _quote);
    await _open(tester, api: api);
    final before = _quoteCalls(api);

    expect(find.text('3 months'), findsOneWidget);
    expect(find.text('12 months'), findsOneWidget);
    expect(find.text('9 months'), findsNothing);

    // Three quick taps → one request after the 300 ms pause.
    await tester.tap(find.text('3 months'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('12 months'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('3 months'));
    await settle(tester);

    expect(_quoteCalls(api) - before, 1);
    expect((api.last('POST', '/quote')!.data as Map)['months'], 3);
  });

  testWidgets('a 422 shows next to the down payment', (tester) async {
    final api = FakeApi()
      ..on(
        'POST',
        '/quote',
        const FakeReply(422, {
          'message': 'Invalid.',
          'errors': {
            'advance': [
              'Down payment must be between PKR 20,000 and PKR 60,000.',
            ],
          },
        }),
      );
    await _open(tester, api: api);

    expect(
      find.text('Down payment must be between PKR 20,000 and PKR 60,000.'),
      findsOneWidget,
    );
  });

  testWidgets('sliders are bounded by the config', (tester) async {
    final api = FakeApi()..onCall('POST', '/quote', _quote);
    await _open(tester, api: api);

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders[0].min, 10000);
    expect(sliders[0].max, 300000);
    expect(sliders[0].divisions, (300000 - 10000) ~/ 5000);
    expect(sliders[1].min, 0.2);
    expect(sliders[1].max, 0.6);
  });
}
