import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/network/auth_interceptor.dart';
import 'package:atompay_mobile/core/network/error_mapper.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStorageProvider),
      ref.watch(sessionEventsProvider),
    ),
  );
  if (kDebugMode && !Env.isProd) {
    // Method, path and status only. Bodies, headers and `extra` carry PII
    // and the token (handbook rule 10), so no LogInterceptor.
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (r, handler) {
          final o = r.requestOptions;
          debugPrint('[api] ${o.method} ${o.path} → ${r.statusCode}');
          handler.next(r);
        },
        onError: (e, handler) {
          final o = e.requestOptions;
          final status = e.response?.statusCode ?? e.type.name;
          debugPrint('[api] ${o.method} ${o.path} → $status');
          handler.next(e);
        },
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

/// Thin wrapper over Dio: unwraps the `{ "data": … }` envelope and turns
/// every failure into an `ApiException`.
class ApiClient {
  new(this._dio);

  final Dio _dio;

  /// Longer timeout for multipart uploads on slow networks (handbook §1.7).
  static const uploadTimeout = Duration(seconds: 120);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  /// The whole body, for paginated lists that need `links` and `meta`.
  Future<Map<String, dynamic>> getPage(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      final body = response.data;
      return body is Map ? body.cast<String, dynamic>() : const {};
    } on Object catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch<dynamic>(path, data: data));

  Future<dynamic> delete(String path, {Object? data}) =>
      _send(() => _dio.delete<dynamic>(path, data: data));

  Future<dynamic> upload(
    String path,
    FormData form, {
    void Function(double progress)? onProgress,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: form,
        options: Options(sendTimeout: uploadTimeout),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      ),
    );
  }

  /// Returns the `data` member, or null for an empty body (204).
  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      return body is Map ? body['data'] : null;
    } on Object catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
