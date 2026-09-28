import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:dio/dio.dart';

/// The only place in the app that reads HTTP status codes (handbook rule 20).
abstract final class ErrorMapper {
  static const _defaultRetryAfter = Duration(seconds: 60);

  static ApiException map(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return const UnexpectedError();

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
        return const NetworkError();
      case DioExceptionType.cancel:
        return const UnexpectedError('Cancelled');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = error.response;
    if (response == null) return const NetworkError();

    final body = response.data;
    final json = body is Map
        ? body.cast<String, dynamic>()
        : const <String, dynamic>{};
    final message = json['message'] is String
        ? json['message'] as String
        : null;

    return switch (response.statusCode ?? 0) {
      401 => Unauthorized(message ?? 'Unauthenticated.'),
      403 => Forbidden(
        message ?? 'Please sign in with an AtomShop customer account.',
      ),
      404 => NotFound(message ?? 'Not found.'),
      409 => Conflict(
        message ?? '',
        code: json['code'] is String ? json['code'] as String : '',
      ),
      422 => Validation(message ?? '', errors: _errors(json['errors'])),
      429 => RateLimited(
        message ?? 'Too Many Attempts.',
        retryAfter: _retryAfter(response.headers),
      ),
      >= 500 && < 600 => const ServerError(),
      _ => const UnexpectedError(),
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
}
