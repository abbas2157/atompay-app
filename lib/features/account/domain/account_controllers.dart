import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>(
  (ref) => ref.watch(authRepositoryProvider).sessions(),
);

/// Signs one device out. Revoking the current one is a sign-out.
Future<void> revokeSession(WidgetRef ref, DeviceSession session) async {
  await ref.read(authRepositoryProvider).revokeSession(session.id);
  if (session.current) {
    await ref.read(authControllerProvider.notifier).signedOutLocally();
  } else {
    ref.invalidate(sessionsProvider);
  }
}

/// `POST /me/delete`. A `409` (instalments still owed) is a general error
/// shown above the button; a wrong password is a `422` on `password`.
final deleteAccountControllerProvider =
    NotifierProvider.autoDispose<DeleteAccountController, FormStatus>(
      DeleteAccountController.new,
    );

class DeleteAccountController extends FormController {
  Future<bool> delete(String password) {
    return run(() async {
      await ref.read(authRepositoryProvider).deleteAccount(password);
      await ref.read(authControllerProvider.notifier).signedOutLocally();
    });
  }
}

/// `GET/PATCH /me/preferences` → `email_alerts` (handbook §8.7).
final emailAlertsProvider =
    AsyncNotifierProvider.autoDispose<EmailAlerts, bool>(EmailAlerts.new);

class EmailAlerts extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final data = await ref.read(apiClientProvider).get('/me/preferences');
    return (data as Map)['email_alerts'] == true;
  }

  /// Optimistic; reverts and rethrows on failure.
  Future<void> set({required bool enabled}) async {
    final previous = state.value;
    state = AsyncData(enabled);
    try {
      final data = await ref
          .read(apiClientProvider)
          .patch('/me/preferences', data: {'email_alerts': enabled});
      if (ref.mounted) state = AsyncData((data as Map)['email_alerts'] == true);
    } on ApiException {
      if (ref.mounted && previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}
