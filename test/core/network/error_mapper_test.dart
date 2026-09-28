import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/network/error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _status(
  int status, [
  Object? body,
  Map<String, List<String>> headers = const {},
]) {
  final options = RequestOptions(path: '/x');
  return ErrorMapper.map(
    DioException.badResponse(
      statusCode: status,
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: body,
        headers: Headers.fromMap(headers),
      ),
    ),
  );
}

void main() {
  test('401 → Unauthorized', () {
    expect(_status(401, {'message': 'Unauthenticated.'}), isA<Unauthorized>());
  });

  test('403 keeps the server message', () {
    final e = _status(403, {'message': 'Please sign in with a customer.'});
    expect(e, isA<Forbidden>());
    expect(e.message, 'Please sign in with a customer.');
  });

  test('404 → NotFound', () {
    expect(_status(404, {'message': 'Nope'}), isA<NotFound>());
  });

  test('409 carries the code', () {
    final e = _status(409, {'message': 'x', 'code': 'profile_required'});
    expect(
      e,
      isA<Conflict>().having((c) => c.code, 'code', 'profile_required'),
    );
  });

  test('422 exposes field errors', () {
    final e = _status(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'login': ['Those details do not match an AtomShop account.'],
        'password': ['Required.', 'Too short.'],
      },
    });
    expect(e, isA<Validation>());
    final v = e as Validation;
    expect(v.first('login'), 'Those details do not match an AtomShop account.');
    expect(v.first('password'), 'Required.');
    expect(v.first('name'), isNull);
  });

  test('429 reads Retry-After, defaulting to 60 s', () {
    final e = _status(
      429,
      {'message': 'Too Many Attempts.'},
      {
        'retry-after': ['42'],
      },
    );
    expect(
      e,
      isA<RateLimited>().having(
        (r) => r.retryAfter,
        'retryAfter',
        const Duration(seconds: 42),
      ),
    );
    expect(
      (_status(429) as RateLimited).retryAfter,
      const Duration(seconds: 60),
    );
  });

  test('5xx never exposes server text', () {
    final e = _status(500, {'message': 'SQLSTATE[42S02] …'});
    expect(e, isA<ServerError>());
    expect(e.message, isNot(contains('SQLSTATE')));
  });

  test('timeouts and connection errors → NetworkError', () {
    final options = RequestOptions(path: '/x');
    for (final e in [
      DioException.connectionTimeout(
        timeout: const Duration(seconds: 15),
        requestOptions: options,
      ),
      DioException.receiveTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      ),
      DioException.connectionError(requestOptions: options, reason: 'x'),
    ]) {
      expect(ErrorMapper.map(e), isA<NetworkError>());
    }
  });

  test('a non-JSON error body still maps by status', () {
    expect(_status(422, '<html>'), isA<Validation>());
  });
}
