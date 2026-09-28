/// Every failed API call surfaces as one of these (handbook §3.4). Screens
/// switch on the type, never on status codes or message strings.
sealed class ApiException implements Exception {
  const new(this.message);

  /// Server text written for customers, or a generic fallback.
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// 401: no, bad, expired or revoked token.
final class Unauthorized extends ApiException {
  const new([super.message = 'Unauthenticated.']);
}

/// 403: not an active customer. On a signed-in route the server has already
/// revoked the token.
final class Forbidden extends ApiException {
  const new(super.message);
}

/// 404: unknown route, or a record that isn't yours.
final class NotFound extends ApiException {
  const new(super.message);
}

/// 409: allowed input, wrong state. Switch on [code] (e.g. `profile_required`).
final class Conflict extends ApiException {
  const new(super.message, {required this.code});

  final String code;
}

/// 422: validation. Show `errors[field].first` under each field; some keys
/// (`signup`, `reset_token`) aren't on screen and are handled by the screen.
final class Validation extends ApiException {
  const new(super.message, {required this.errors});

  final Map<String, List<String>> errors;

  String? first(String field) {
    final list = errors[field];
    return list == null || list.isEmpty ? null : list.first;
  }
}

/// 429: disable the button and count down from [retryAfter].
final class RateLimited extends ApiException {
  const new(super.message, {required this.retryAfter});

  final Duration retryAfter;
}

/// 5xx. Never show the raw server text.
final class ServerError extends ApiException {
  const new([super.message = 'Server Error']);
}

/// Timeout, no connection, TLS failure.
final class NetworkError extends ApiException {
  const new([super.message = 'No connection']);
}

/// Anything the mapper couldn't classify (a malformed body, a cancelled call).
final class UnexpectedError extends ApiException {
  const new([super.message = 'Unexpected error']);
}
