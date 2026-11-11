import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:dio/dio.dart';

/// The only place in the app that reads HTTP status codes.
abstract final class ErrorMapper {
  static const _defaultRetryAfter = Duration(seconds: 60);

  static ApiException map(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return const Server(statusCode: 0);
    if (error.error is ApiException) return error.error! as ApiException;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const Timeout();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const Offline();
      case DioExceptionType.cancel:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = error.response;
    if (response == null) return const Offline();

    final body = response.data;
    final json = body is Map
        ? body.cast<String, dynamic>()
        : const <String, dynamic>{};
    final message = json['message'] is String
        ? json['message'] as String
        : null;
    final status = response.statusCode ?? 0;

    return switch (status) {
      401 => Unauthenticated(message ?? 'Unauthenticated.'),
      403 => message == null ? const Forbidden() : Forbidden(message),
      404 => NotFound(message ?? 'Not found.'),
      409 => Conflict(
        message ?? '',
        code: json['code'] is String ? json['code'] as String : '',
      ),
      422 => Validation(message ?? '', fieldErrors: _errors(json['errors'])),
      429 => RateLimited(
        message ?? 'Too Many Attempts.',
        retryAfter: _retryAfter(response.headers),
      ),
      _ => Server(
        statusCode: status,
        reference: response.headers.value('x-request-id') ?? _localRef(),
      ),
    };
  }

  static Map<String, List<String>> _errors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is List)
          '${entry.key}': [for (final m in entry.value as List) '$m'],
    };
  }

  static Duration _retryAfter(Headers headers) {
    final seconds = int.tryParse(headers.value('retry-after') ?? '');
    return seconds == null || seconds <= 0
        ? _defaultRetryAfter
        : Duration(seconds: seconds);
  }

  /// A short code the customer can read out to support, e.g. `E-7K2Q9`.
  static String _localRef() {
    final n = AppClock.now().millisecondsSinceEpoch % 60466176;
    return 'E-${n.toRadixString(36).toUpperCase().padLeft(5, '0')}';
  }
}
