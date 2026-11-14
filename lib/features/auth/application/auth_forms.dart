import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- sign in ----------------------------------------------------------------

class SignInForm extends FormController {
  Future<bool> submit({required String login, required String password}) async {
    final session = await run(
      () => ref
          .read(authRepositoryProvider)
          .login(login: login, password: password),
    );
    if (session == null) return false;
    await ref.read(sessionProvider.notifier).start(session);
    return true;
  }
}

final signInFormProvider = NotifierProvider.autoDispose<SignInForm, FormStatus>(
  SignInForm.new,
);

// ---- sign up ----------------------------------------------------------------

/// What sign-up has collected so far: kept while the customer moves between
/// the details and code screens.
@immutable
class SignupDraft {
  const new({
    this.name = '',
    this.login = '',
    this.sent,
    this.sentAt,
    this.restartReason,
  });

  final String name;
  final String login;
  final CodeSent? sent;
  final DateTime? sentAt;

  /// Set when the code screen sends the customer back ("This sign-up has
  /// expired. Please start again.").
  final String? restartReason;
}

class SignupFlow extends Notifier<SignupDraft> {
  @override
  SignupDraft build() => const SignupDraft();

  void codeSent({
    required String name,
    required String login,
    required CodeSent sent,
  }) => state = SignupDraft(
    name: name,
    login: login,
    sent: sent,
    sentAt: DateTime.now(),
  );

  void resent(CodeSent sent) => state = SignupDraft(
    name: state.name,
    login: state.login,
    sent: sent,
    sentAt: DateTime.now(),
  );

  void restart(String reason) => state = SignupDraft(
    name: state.name,
    login: state.login,
    restartReason: reason,
  );

  void clear() => state = const SignupDraft();
}

final signupFlowProvider = NotifierProvider<SignupFlow, SignupDraft>(
  SignupFlow.new,
);

class SignUpForm extends FormController {
  Future<bool> submit({
    required String name,
    required String login,
    required String password,
    required String confirmation,
  }) async {
    final sent = await run(
      () => ref
          .read(authRepositoryProvider)
          .register(
            name: name,
            login: login,
            password: password,
            passwordConfirmation: confirmation,
          ),
    );
    if (sent == null) return false;
    ref
        .read(signupFlowProvider.notifier)
        .codeSent(name: name, login: login, sent: sent);
    return true;
  }
}

final signUpFormProvider = NotifierProvider.autoDispose<SignUpForm, FormStatus>(
  SignUpForm.new,
);

enum VerifyOutcome { signedIn, wrongCode, restart }

class VerifySignupForm extends FormController {
  Future<VerifyOutcome> submit(String code) async {
    final draft = ref.read(signupFlowProvider);
    final id = draft.sent?.id;
    if (id == null) return VerifyOutcome.restart;
    final session = await run(
      () => ref
          .read(authRepositoryProvider)
          .verifySignup(signupId: id, code: code),
    );
    if (session != null) {
      await ref.read(sessionProvider.notifier).start(session);
      ref.read(signupFlowProvider.notifier).clear();
      return VerifyOutcome.signedIn;
    }
    // `signup` errors all mean: go back to the details screen.
    final restart = state.field('signup');
    if (restart != null) {
      ref.read(signupFlowProvider.notifier).restart(restart);
      return VerifyOutcome.restart;
    }
    return VerifyOutcome.wrongCode;
  }

  Future<void> resend() async {
    final id = ref.read(signupFlowProvider).sent?.id;
    if (id == null) return;
    final sent = await run(
      () => ref.read(authRepositoryProvider).resendSignupCode(id),
    );
    if (sent != null) ref.read(signupFlowProvider.notifier).resent(sent);
  }
}

final verifySignupFormProvider =
    NotifierProvider.autoDispose<VerifySignupForm, FormStatus>(
      VerifySignupForm.new,
    );

// ---- forgot password --------------------------------------------------------

@immutable
class ResetDraft {
  const new({
    this.login = '',
    this.sent,
    this.sentAt,
    this.resetToken,
    this.restartReason,
  });

  final String login;
  final CodeSent? sent;
  final DateTime? sentAt;
  final String? resetToken;
  final String? restartReason;
}

class ResetFlow extends Notifier<ResetDraft> {
  @override
  ResetDraft build() => const ResetDraft();

  void codeSent(String login, CodeSent sent) =>
      state = ResetDraft(login: login, sent: sent, sentAt: DateTime.now());

  void verified(String token) => state = ResetDraft(
    login: state.login,
    sent: state.sent,
    sentAt: state.sentAt,
    resetToken: token,
  );

  void restart(String reason) =>
      state = ResetDraft(login: state.login, restartReason: reason);

  void clear() => state = const ResetDraft();
}

final resetFlowProvider = NotifierProvider<ResetFlow, ResetDraft>(
  ResetFlow.new,
);

class ForgotForm extends FormController {
  Future<bool> send(String login) async {
    final sent = await run(
      () => ref.read(authRepositoryProvider).forgotPassword(login),
    );
    if (sent == null) return false;
    ref.read(resetFlowProvider.notifier).codeSent(login, sent);
    return true;
  }
}

final forgotFormProvider = NotifierProvider.autoDispose<ForgotForm, FormStatus>(
  ForgotForm.new,
);

class ForgotCodeForm extends FormController {
  Future<VerifyOutcome> verify(String code) async {
    final id = ref.read(resetFlowProvider).sent?.id;
    if (id == null) return VerifyOutcome.restart;
    final token = await run(
      () => ref
          .read(authRepositoryProvider)
          .verifyResetCode(requestId: id, code: code),
    );
    if (token != null) {
      ref.read(resetFlowProvider.notifier).verified(token);
      return VerifyOutcome.signedIn;
    }
    // "Too many wrong codes" and "expired" mean: request a new code.
    final message = state.field('code') ?? '';
    final lower = message.toLowerCase();
    if (lower.contains('too many') || lower.contains('expired')) {
      ref.read(resetFlowProvider.notifier).restart(message);
      return VerifyOutcome.restart;
    }
    return VerifyOutcome.wrongCode;
  }

  Future<void> resend() async {
    final login = ref.read(resetFlowProvider).login;
    final sent = await run(
      () => ref.read(authRepositoryProvider).forgotPassword(login),
    );
    if (sent != null) {
      ref.read(resetFlowProvider.notifier).codeSent(login, sent);
    }
  }
}

final forgotCodeFormProvider =
    NotifierProvider.autoDispose<ForgotCodeForm, FormStatus>(
      ForgotCodeForm.new,
    );

class NewPasswordForm extends FormController {
  Future<VerifyOutcome> submit({
    required String password,
    required String confirmation,
  }) async {
    final token = ref.read(resetFlowProvider).resetToken;
    if (token == null) return VerifyOutcome.restart;
    final session = await run(
      () => ref
          .read(authRepositoryProvider)
          .resetPassword(
            resetToken: token,
            password: password,
            passwordConfirmation: confirmation,
          ),
    );
    if (session != null) {
      await ref.read(sessionProvider.notifier).start(session);
      ref.read(resetFlowProvider.notifier).clear();
      return VerifyOutcome.signedIn;
    }
    final expired = state.field('reset_token');
    if (expired != null) {
      ref.read(resetFlowProvider.notifier).restart(expired);
      return VerifyOutcome.restart;
    }
    return VerifyOutcome.wrongCode;
  }
}

final newPasswordFormProvider =
    NotifierProvider.autoDispose<NewPasswordForm, FormStatus>(
      NewPasswordForm.new,
    );

/// Client-side checks that mirror the server, for instant feedback.
abstract final class AuthChecks {
  static String? password(String value) =>
      value.length < 8 ? 'Use at least 8 characters.' : null;

  static String? confirmation(String password, String confirmation) =>
      password == confirmation ? null : "The passwords don't match.";

  static String? required(String value, String message) =>
      value.trim().isEmpty ? message : null;

  /// The server gives a precise reason; this only stops an empty submit.
  static bool isValidCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);
}

/// Used by screens to tell an expired flow apart from a fresh one.
bool isRestartError(ApiException? e) =>
    e is Validation &&
    (e.first('signup') != null || e.first('reset_token') != null);
