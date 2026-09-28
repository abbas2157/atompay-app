import 'dart:async';

import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// Broadcasts "the server ended this session" so the auth controller can sign
/// out without the network layer depending on it. The value is the message to
/// show (a 403's text), or null for a plain 401.
class SessionEvents {
  final _ended = StreamController<String?>.broadcast();

  Stream<String?> get ended => _ended.stream;

  void end(String? message) => _ended.add(message);

  Future<void> dispose() => _ended.close();
}

/// Adds the bearer token, and on 401/403 from a signed-in call clears it and
/// reports the session as ended (handbook §3.4).
class AuthInterceptor extends Interceptor {
  new(this._tokens, this._events);

  final TokenStorage _tokens;
  final SessionEvents _events;

  static const _sentTokenKey = 'auth.sentToken';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_sentTokenKey] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final sentToken = err.requestOptions.extra[_sentTokenKey];
    // Only a call that carried the *current* token ends the session. A 403 at
    // sign-in carries no token, and a late reply to an old token is stale.
    if ((status == 401 || status == 403) &&
        sentToken != null &&
        sentToken == _tokens.token) {
      await _tokens.clear();
      final data = err.response?.data;
      final message = status == 403 && data is Map && data['message'] is String
          ? data['message'] as String
          : null;
      _events.end(message);
    }
    handler.next(err);
  }
}
