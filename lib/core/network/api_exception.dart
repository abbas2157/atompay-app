/// Every failed API call surfaces as one of these (brief §3). Screens switch
/// on the type, never on status codes or message strings.
sealed class ApiException implements Exception {
  const new(this.message);

  /// Server text written for customers, or a generic fallback. Never shown
  /// for [Server].
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// 401: no, bad, expired or revoked token.
final class Unauthenticated extends ApiException {
  const new([super.message = 'Unauthenticated.']);
}

/// 403: not an active customer. On a signed-in route the server has already
/// revoked the token.
final class Forbidden extends ApiException {
  const new([
    super.message = 'Please sign in with an AtomShop customer account.',
  ]);
}

/// 404: unknown route, or a record that isn't yours.
final class NotFound extends ApiException {
  const new([super.message = 'Not found.']);
}

/// 409: allowed input, wrong state. Switch on [code]
/// (`profile_required`, `nothing_changed`, `outstanding_balance`).
final class Conflict extends ApiException {
  const new(super.message, {required this.code});

  final String code;
}

/// 422: show `fieldErrors[field].first` under each field. Some keys
/// (`signup`, `reset_token`) are not on screen; the screen handles those.
final class Validation extends ApiException {
  const new(super.message, {required this.fieldErrors});

  final Map<String, List<String>> fieldErrors;

  String? first(String field) {
    final list = fieldErrors[field];
    return list == null || list.isEmpty ? null : list.first;
  }

  Validation without(String field) =>
      Validation(message, fieldErrors: Map.of(fieldErrors)..remove(field));
}

/// 429: disable the button and count down from [retryAfter].
final class RateLimited extends ApiException {
  const new(super.message, {required this.retryAfter});

  final Duration retryAfter;
}

/// 5xx. Never show the raw text; show [reference] so support can find it.
final class Server extends ApiException {
  const new({this.statusCode = 500, this.reference}) : super('Server Error');

  final int statusCode;

  /// The server's request id when it sends one, else a short local code.
  final String? reference;

  /// 503 is how `php artisan down` answers: the app shows Maintenance.
  bool get isMaintenance => statusCode == 503;
}

/// No connection, DNS or TLS failure.
final class Offline extends ApiException {
  const new() : super('No connection');
}

/// Connect, send or receive timed out.
final class Timeout extends ApiException {
  const new() : super('Timed out');
}
