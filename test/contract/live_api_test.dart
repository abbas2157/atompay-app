// Contract check against a real server. Skipped unless a URL is given:
//   flutter test test/contract --dart-define=LIVE_API=http://localhost/atompay/api/v1
// Read-only apart from one failed login (counts toward its rate limit).
@Tags(['live'])
library;

import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/calculator/data/calculator_models.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = String.fromEnvironment('LIVE_API');

void main() {
  final skip = _base.isEmpty ? 'pass --dart-define=LIVE_API=<base url>' : null;
  final api = ApiClient(
    Dio(
      BaseOptions(
        // Empty at analysis time, set via --dart-define at run time.
        // ignore: avoid_redundant_argument_values
        baseUrl: _base,
        headers: {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
  );

  Map<String, dynamic> map(Object? d) => (d! as Map).cast<String, dynamic>();

  test('GET /app-config parses', () async {
    final config = AppConfig.fromJson(map(await api.get('/app-config')));
    expect(config.minVersion.android, isNotNull);
    expect(config.features.signupChannels, contains('email'));
  }, skip: skip);

  test('GET /options parses', () async {
    final options = FormOptions.fromJson(map(await api.get('/options')));
    expect(options.employmentStatuses, isNotEmpty);
    expect(options.incomeSources, isNotEmpty);
  }, skip: skip);

  test('GET /calculator parses', () async {
    final c = CalculatorConfig.fromJson(map(await api.get('/calculator')));
    expect(c.tenures, isNotEmpty);
    expect(c.price.min, lessThan(c.price.max));
  }, skip: skip);

  test('POST /quote parses and uses the requested inputs', () async {
    final c = CalculatorConfig.fromJson(map(await api.get('/calculator')));
    final price = c.price.min + c.price.step * 2;
    final months = c.tenures.first;
    final q = Quote.fromJson(
      map(
        await api.post(
          '/quote',
          data: {'price': price, 'months': months, 'advance': price ~/ 4},
        ),
      ),
    );
    expect(q.price, price);
    expect(q.months, months);
    expect(q.monthly, greaterThan(0));
  }, skip: skip);

  test('POST /estimate parses', () async {
    final e = Estimate.fromJson(
      map(await api.post('/estimate', data: {'monthly_income': 150000})),
    );
    expect(e.estimatedLimit, isA<int>());
  }, skip: skip);

  test('GET /me without a token is Unauthorized', () async {
    await expectLater(api.get('/me'), throwsA(isA<Unauthorized>()));
  }, skip: skip);

  test('bad login is a 422 on the login field', () async {
    await expectLater(
      api.post(
        '/auth/login',
        data: {'login': 'no-such-user@example.invalid', 'password': 'x' * 8},
      ),
      throwsA(
        isA<Validation>().having((v) => v.first('login'), 'login', isNotNull),
      ),
    );
  }, skip: skip);
}
