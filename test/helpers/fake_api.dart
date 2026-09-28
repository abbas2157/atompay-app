import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeReply {
  const new(this.status, [this.body, this.headers = const {}]);

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

/// Serves canned JSON by `METHOD /path` and records every request, so tests
/// run the real Dio stack and interceptors without a network.
class FakeApi implements HttpClientAdapter {
  final _routes = <String, FakeReply Function(RequestOptions)>{};
  final requests = <RequestOptions>[];

  void on(String method, String path, FakeReply reply) =>
      _routes['$method $path'] = (_) => reply;

  void onCall(
    String method,
    String path,
    FakeReply Function(RequestOptions r) reply,
  ) => _routes['$method $path'] = reply;

  /// The last request to [path], if any.
  RequestOptions? last(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).lastOrNull;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = _routes['${options.method} ${options.path}'];
    if (handler == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No fake route for ${options.method} ${options.path}',
      );
    }
    final reply = handler(options);
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final MapEntry(:key, :value) in reply.headers.entries)
          key: [value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
