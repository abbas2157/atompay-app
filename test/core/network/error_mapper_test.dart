import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/network/error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;

DioException response(
  int status, [
  Object? body,
  Map<String, List<String>> headers = const {},
]) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers),
    ),
  );
}

void main() {
  test('401 → Unauthenticated', () {
    expect(ErrorMapper.map(response(401)), isA<Unauthenticated>());
  });

  test('403 keeps the server message', () {
    final e = ErrorMapper.map(response(403, {'message': 'Not a customer.'}));
    expect(e, isA<Forbidden>());
    expect(e.message, 'Not a customer.');
  });

  test('404 → NotFound', () {
    expect(ErrorMapper.map(response(404)), isA<NotFound>());
  });

  test('409 carries its code', () {
    final e = ErrorMapper.map(
      response(409, {'message': 'Owed.', 'code': 'outstanding_balance'}),
    );
    expect(
      e,
      isA<Conflict>().having((c) => c.code, 'code', 'outstanding_balance'),
    );
  });

  test('422 keeps every field error', () {
    final e = ErrorMapper.map(
      response(422, {
        'message': 'Bad.',
        'errors': {
          'login': ['Those details do not match an AtomShop account.'],
        },
      }),
    );
    expect(e, isA<Validation>());
    expect(
      (e as Validation).first('login'),
      'Those details do not match an AtomShop account.',
    );
  });

  test('429 reads Retry-After, defaulting to a minute', () {
    final e = ErrorMapper.map(
      response(429, null, {
        'retry-after': ['48'],
      }),
    );
    expect(
      e,
      isA<RateLimited>().having(
        (r) => r.retryAfter,
        'retryAfter',
        const Duration(seconds: 48),
      ),
    );
    final d = ErrorMapper.map(response(429)) as RateLimited;
    expect(d.retryAfter, const Duration(seconds: 60));
  });

  test('5xx never carries server text, and 503 means maintenance', () {
    final e = ErrorMapper.map(response(500, {'message': 'SQLSTATE[42S22]'}));
    expect(e, isA<Server>());
    expect(e.message, isNot(contains('SQL')));
    expect((e as Server).reference, isNotNull);
    expect((ErrorMapper.map(response(503)) as Server).isMaintenance, isTrue);
  });

  test('timeouts and connection errors', () {
    final o = RequestOptions(path: '/x');
    expect(
      ErrorMapper.map(
        DioException(requestOptions: o, type: DioExceptionType.receiveTimeout),
      ),
      isA<Timeout>(),
    );
    expect(
      ErrorMapper.map(
        DioException(requestOptions: o, type: DioExceptionType.connectionError),
      ),
      isA<Offline>(),
    );
  });
}
