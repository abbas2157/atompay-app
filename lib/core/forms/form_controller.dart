import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What every submitting form shares: in flight, the last error, and a 429
/// lock-out.
@immutable
class FormStatus {
  const new({this.busy = false, this.error, this.blockedUntil});

  final bool busy;
  final ApiException? error;

  /// From `Retry-After`. The submit button stays disabled until then.
  final DateTime? blockedUntil;

  /// The first server message for [name] from a 422.
  String? field(String name) => switch (error) {
    final Validation v => v.first(name),
    _ => null,
  };

  bool get blocked =>
      blockedUntil != null && DateTime.now().isBefore(blockedUntil!);

  Duration get retryIn => blockedUntil == null
      ? Duration.zero
      : blockedUntil!.difference(DateTime.now());

  /// A message for errors that don't belong to a field: shown as a note
  /// above the button. Null for field errors, 429 (countdown) and 401
  /// (handled by the session).
  String? generalMessage(Set<String> fieldsOnScreen) => switch (error) {
    null || RateLimited() || Unauthenticated() => null,
    final Validation v =>
      v.fieldErrors.keys.any(fieldsOnScreen.contains) ? null : v.message,
    Offline() => "You're offline. Check your connection and try again.",
    Timeout() => 'This is taking too long. Please try again.',
    final Server s =>
      'Something went wrong on our side. Please try again'
          '${s.reference == null ? '' : ' (reference ${s.reference})'}.',
    final ApiException e => e.message,
  };
}

/// Base for form controllers. Subclasses expose intention-named methods that
/// wrap their API call in [run].
abstract class FormController extends Notifier<FormStatus> {
  @override
  FormStatus build() => const FormStatus();

  /// Runs [action] unless a submit is already in flight. Returns its result,
  /// or null on failure (the error is then in [state]).
  @protected
  Future<T?> run<T>(Future<T> Function() action) async {
    if (state.busy || state.blocked) return null;
    state = FormStatus(busy: true, blockedUntil: state.blockedUntil);
    try {
      final result = await action();
      if (ref.mounted) state = const FormStatus();
      return result;
    } on ApiException catch (e) {
      if (ref.mounted) {
        state = FormStatus(
          error: e,
          blockedUntil: e is RateLimited
              ? DateTime.now().add(e.retryAfter)
              : state.blockedUntil,
        );
      }
      return null;
    }
  }

  /// Drops a field's error once the user edits it.
  void clearField(String name) {
    final error = state.error;
    if (error is! Validation || error.first(name) == null) return;
    final rest = error.without(name);
    state = FormStatus(
      blockedUntil: state.blockedUntil,
      error: rest.fieldErrors.isEmpty ? null : rest,
    );
  }

  void clearError() => state = FormStatus(blockedUntil: state.blockedUntil);

  /// Shows a client-side field error without calling the server.
  void fail(Map<String, String> errors) => state = FormStatus(
    blockedUntil: state.blockedUntil,
    error: Validation(
      'Check the highlighted fields.',
      fieldErrors: {
        for (final e in errors.entries) e.key: [e.value],
      },
    ),
  );
}
