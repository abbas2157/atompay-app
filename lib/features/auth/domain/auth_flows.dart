import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A code in flight: what was sent, and when "send a new code" unlocks.
@immutable
class PendingCode {
  const new({required this.challenge, required this.resendAt});

  factory from(CodeChallenge c) => PendingCode(
    challenge: c,
    resendAt: DateTime.now().add(Duration(seconds: c.resendIn)),
  );

  final CodeChallenge challenge;
  final DateTime resendAt;
}

// ---------------------------------------------------------------- sign in

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, FormStatus>(
      SignInController.new,
    );

class SignInController extends FormController {
  Future<bool> submit({required String login, required String password}) {
    return run(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .login(login: login, password: password);
      ref.read(authControllerProvider.notifier).signedIn(user);
    });
  }
}

// ---------------------------------------------------------------- sign up

/// The sign-up in progress. Memory only: if the app is killed, the user
/// starts again (handbook §5.4).
final pendingSignupProvider = NotifierProvider<PendingSignup, PendingCode?>(
  PendingSignup.new,
);

class PendingSignup extends Notifier<PendingCode?> {
  @override
  PendingCode? build() => null;

  void set(CodeChallenge c) => state = PendingCode.from(c);

  void clear() => state = null;
}

final signUpControllerProvider =
    NotifierProvider.autoDispose<SignUpController, FormStatus>(
      SignUpController.new,
    );

class SignUpController extends FormController {
  Future<bool> submit({
    required String name,
    required String login,
    required String password,
    required String passwordConfirmation,
  }) {
    return run(() async {
      final challenge = await ref
          .read(authRepositoryProvider)
          .register(
            name: name,
            login: login,
            password: password,
            passwordConfirmation: passwordConfirmation,
          );
      ref.read(pendingSignupProvider.notifier).set(challenge);
    });
  }
}

final signUpVerifyControllerProvider =
    NotifierProvider.autoDispose<SignUpVerifyController, FormStatus>(
      SignUpVerifyController.new,
    );

class SignUpVerifyController extends FormController {
  Future<bool> verify(String code) {
    final pending = ref.read(pendingSignupProvider);
    if (pending == null) return Future.value(false);
    return run(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .verifySignup(signupId: pending.challenge.id, code: code);
      ref.read(pendingSignupProvider.notifier).clear();
      ref.read(authControllerProvider.notifier).signedIn(user);
    });
  }

  Future<bool> resend() {
    final pending = ref.read(pendingSignupProvider);
    if (pending == null) return Future.value(false);
    return run(() async {
      final challenge = await ref
          .read(authRepositoryProvider)
          .resendSignupCode(pending.challenge.id);
      ref.read(pendingSignupProvider.notifier).set(challenge);
    });
  }
}

// -------------------------------------------------------- forgot password

@immutable
class ResetFlow {
  const new({required this.login, required this.code, this.resetToken});

  final String login;
  final PendingCode code;

  /// Set once the code is verified (valid 15 minutes).
  final String? resetToken;
}

final resetFlowProvider = NotifierProvider<ResetFlowHolder, ResetFlow?>(
  ResetFlowHolder.new,
);

class ResetFlowHolder extends Notifier<ResetFlow?> {
  @override
  ResetFlow? build() => null;

  void started(String login, CodeChallenge c) =>
      state = ResetFlow(login: login, code: PendingCode.from(c));

  void verified(String resetToken) {
    final s = state;
    if (s != null) {
      state = ResetFlow(login: s.login, code: s.code, resetToken: resetToken);
    }
  }

  void clear() => state = null;
}

final forgotControllerProvider =
    NotifierProvider.autoDispose<ForgotController, FormStatus>(
      ForgotController.new,
    );

class ForgotController extends FormController {
  Future<bool> request(String login) {
    return run(() async {
      final challenge = await ref
          .read(authRepositoryProvider)
          .forgotPassword(login);
      ref.read(resetFlowProvider.notifier).started(login.trim(), challenge);
    });
  }
}

final forgotVerifyControllerProvider =
    NotifierProvider.autoDispose<ForgotVerifyController, FormStatus>(
      ForgotVerifyController.new,
    );

class ForgotVerifyController extends FormController {
  Future<bool> verify(String code) {
    final flow = ref.read(resetFlowProvider);
    if (flow == null) return Future.value(false);
    return run(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyResetCode(requestId: flow.code.challenge.id, code: code);
      ref.read(resetFlowProvider.notifier).verified(token);
    });
  }

  /// Resend = ask again with the same login. Within 60 s the server returns
  /// the same request and sends nothing new (handbook §5.5).
  Future<bool> resend() {
    final flow = ref.read(resetFlowProvider);
    if (flow == null) return Future.value(false);
    return run(() async {
      final challenge = await ref
          .read(authRepositoryProvider)
          .forgotPassword(flow.login);
      ref.read(resetFlowProvider.notifier).started(flow.login, challenge);
    });
  }
}

/// "Too many wrong codes" and "expired" mean the request is dead: back to
/// step 1 (handbook §5.5). "N tries left" stays on the code screen.
bool isDeadResetCode(String message) {
  final m = message.toLowerCase();
  return m.contains('too many') || m.contains('expired');
}

final forgotResetControllerProvider =
    NotifierProvider.autoDispose<ForgotResetController, FormStatus>(
      ForgotResetController.new,
    );

class ForgotResetController extends FormController {
  Future<bool> reset({
    required String password,
    required String passwordConfirmation,
  }) {
    final token = ref.read(resetFlowProvider)?.resetToken;
    if (token == null) return Future.value(false);
    return run(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            resetToken: token,
            password: password,
            passwordConfirmation: passwordConfirmation,
          );
      ref.read(resetFlowProvider.notifier).clear();
      ref.read(authControllerProvider.notifier).signedIn(user);
    });
  }
}
