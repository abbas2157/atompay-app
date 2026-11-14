import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "Version 1.0.0 (1)".
String versionLabel(PackageInfo p) => 'Version ${p.version} (${p.buildNumber})';

/// "0300 •••3707": the mobile number masked (brief §7.2: shown, not
/// edited; it changes on Atomshop.pk).
String? maskedMobile(User u) {
  final digits = (u.phone ?? u.phoneFormatted ?? '').replaceAll(
    RegExp(r'\D'),
    '',
  );
  if (digits.length < 8) return null;
  return '${digits.substring(0, 4)} •••${digits.substring(digits.length - 4)}';
}

/// `GET /auth/sessions`.
final sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(authRepositoryProvider).sessions();
});

/// `GET /me/preferences` → `email_alerts`.
final emailAlertsProvider =
    AsyncNotifierProvider.autoDispose<EmailAlerts, bool>(EmailAlerts.new);

class EmailAlerts extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    ref.watch(sessionUserIdProvider);
    return ref.watch(authRepositoryProvider).emailAlerts();
  }

  /// Optimistic; rolls back and rethrows when the server says no.
  Future<void> set({required bool on}) async {
    final before = state.value;
    state = AsyncData(on);
    try {
      final saved = await ref
          .read(authRepositoryProvider)
          .setEmailAlerts(on: on);
      if (ref.mounted) state = AsyncData(saved);
    } on ApiException {
      if (ref.mounted && before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final changePasswordFormProvider =
    NotifierProvider.autoDispose<ChangePasswordForm, FormStatus>(
      ChangePasswordForm.new,
    );

/// `POST /me/password`. Other sessions are signed out by the server.
class ChangePasswordForm extends FormController {
  Future<bool> submit({
    required String current,
    required String password,
    required String confirmation,
  }) async {
    final errors = {
      if (current.isEmpty) 'current_password': 'Enter your current password.',
      if (password.length < 8) 'password': 'At least 8 characters.',
      if (password.length >= 8 && confirmation != password)
        'password_confirmation': "The passwords don't match.",
    };
    if (errors.isNotEmpty) {
      fail(errors);
      return false;
    }
    final ok = await run(() async {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            current: current,
            password: password,
            passwordConfirmation: confirmation,
          );
      return true;
    });
    return ok ?? false;
  }
}

/// What deleting the account came to.
enum DeleteOutcome { deleted, blocked }

final deleteAccountFormProvider =
    NotifierProvider.autoDispose<DeleteAccountForm, FormStatus>(
      DeleteAccountForm.new,
    );

/// `POST /me/delete`; 409 `outstanding_balance` while anything is owed.
class DeleteAccountForm extends FormController {
  Future<DeleteOutcome?> submit(String password) async {
    if (password.isEmpty) {
      fail({'password': 'Enter your password to confirm.'});
      return null;
    }
    final done = await run(() async {
      await ref.read(authRepositoryProvider).deleteAccount(password);
      return true;
    });
    if (done ?? false) {
      await ref.read(sessionProvider.notifier).ended();
      return DeleteOutcome.deleted;
    }
    if (state.error case Conflict(code: 'outstanding_balance')) {
      clearError();
      return DeleteOutcome.blocked;
    }
    return null;
  }
}
