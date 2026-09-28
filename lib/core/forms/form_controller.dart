import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The state every submitting form shares: in flight, last error, and a
/// `429` lock-out.
@immutable
class FormStatus {
  const new({this.busy = false, this.error, this.blockedUntil});

  final bool busy;
  final ApiException? error;

  /// Set from `Retry-After`. The submit button stays disabled until then.
  final DateTime? blockedUntil;

  /// The first server message for [field] from a `422`.
  String? field(String name) => switch (error) {
    final Validation v => v.first(name),
    _ => null,
  };

  /// True when the error isn't a field error: show it as a message.
  bool get hasGeneralError => switch (error) {
    null || Validation() || RateLimited() => false,
    _ => true,
  };
}

/// Base for form screens' controllers. Subclasses expose intention-named
/// methods that wrap their API call in [run].
abstract class FormController extends Notifier<FormStatus> {
  @override
  FormStatus build() => const FormStatus();

  /// Runs [action] unless a submit is already in flight (handbook rule 25).
  /// Returns true on success; on failure the error is in [state].
  @protected
  Future<bool> run(Future<void> Function() action) async {
    if (state.busy) return false;
    state = FormStatus(busy: true, blockedUntil: state.blockedUntil);
    try {
      await action();
      if (ref.mounted) state = const FormStatus();
      return true;
    } on ApiException catch (e) {
      if (ref.mounted) {
        state = FormStatus(
          error: e,
          blockedUntil: e is RateLimited
              ? DateTime.now().add(e.retryAfter)
              : state.blockedUntil,
        );
      }
      return false;
    }
  }

  /// Drops a field's error once the user edits it.
  void clearField(String name) {
    final error = state.error;
    if (error is! Validation || !error.errors.containsKey(name)) return;
    final rest = Map.of(error.errors)..remove(name);
    state = FormStatus(
      blockedUntil: state.blockedUntil,
      error: rest.isEmpty ? null : Validation(error.message, errors: rest),
    );
  }

  void clearError() => state = FormStatus(blockedUntil: state.blockedUntil);
}
