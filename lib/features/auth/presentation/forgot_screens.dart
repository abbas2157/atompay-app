import 'dart:async';

import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/forms/validators.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/otp_field.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_flows.dart';
import 'package:atompay_mobile/features/auth/presentation/code_entry.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Step 1: email or mobile (handbook §5.5). [initialLogin] pre-fills it when
/// opened from Account → Change password.
class ForgotScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialLogin});

  final String? initialLogin;

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  late final _login = TextEditingController(text: widget.initialLogin);
  String? _local;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailOnly = !ref.read(appConfigProvider).features.resetByWhatsapp;
    final error = Validators(context.l10n)
        .login(_login.text, emailOnly: emailOnly);
    setState(() => _local = error);
    if (error != null) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(forgotControllerProvider.notifier)
        .request(_login.text);
    if (ok && mounted) await context.push(Routes.forgotVerify);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(forgotControllerProvider);
    final byWhatsapp = ref.watch(appConfigProvider).features.resetByWhatsapp;

    return AuthScaffold(
      headline: l10n.forgotHeadline,
      intro: l10n.forgotIntro,
      showBack: true,
      children: [
        LoginField(
          label: byWhatsapp ? l10n.loginLabel : l10n.emailLabel,
          hintText: byWhatsapp ? l10n.loginHint : l10n.emailHint,
          controller: _login,
          emailOnly: !byWhatsapp,
          textInputAction: TextInputAction.done,
          errorText: _local ?? status.field('login'),
          helperFor: (_) => byWhatsapp ? l10n.forgotWhatsappNote : null,
          onChanged: (_) {
            ref.read(forgotControllerProvider.notifier).clearField('login');
            if (_local != null) setState(() => _local = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.x24),
        SubmitSection(
          status: status,
          label: l10n.sendCodeButton,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Step 2: the code. Resend asks `/auth/password/forgot` again.
class ForgotVerifyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ForgotVerifyScreen> createState() => _ForgotVerifyScreenState();
}

class _ForgotVerifyScreenState extends ConsumerState<ForgotVerifyScreen> {
  final _code = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length < OtpField.length) {
      setState(() => _local = context.l10n.codeIncomplete);
      return;
    }
    setState(() => _local = null);
    final ok = await ref
        .read(forgotVerifyControllerProvider.notifier)
        .verify(_code.text);
    if (ok && mounted) await context.push(Routes.forgotReset);
  }

  Future<void> _resend() async {
    final ok = await ref.read(forgotVerifyControllerProvider.notifier).resend();
    if (ok && mounted) {
      _code.clear();
      showToast(context.l10n.codeResent);
    }
  }

  Future<void> _backToStart(String message) async {
    await showMessageDialog(
      context,
      title: context.l10n.startAgainTitle,
      message: message,
    );
    if (mounted) context.go(Routes.forgot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = ref.watch(resetFlowProvider);
    final status = ref.watch(forgotVerifyControllerProvider);

    ref.listen(forgotVerifyControllerProvider, (_, next) {
      if (next.error case final Validation v) {
        final m = v.first('code');
        if (m == null) return;
        _code.clear();
        if (isDeadResetCode(m)) unawaited(_backToStart(m));
      }
    });

    if (flow == null) {
      return AuthScaffold(
        headline: l10n.startAgainTitle,
        showBack: true,
        children: const [],
      );
    }

    return AuthScaffold(
      headline: l10n.enterCodeHeadline,
      showBack: true,
      children: [
        CodeEntry(
          // Neutral wording: never reveals whether the account exists.
          sentTo: l10n.forgotNeutral(flow.code.challenge.destination),
          code: _code,
          status: status,
          codeError: _local ?? status.field('code'),
          resendAt: flow.code.resendAt,
          submitLabel: l10n.verifyCodeButton,
          onSubmit: _verify,
          onResend: _resend,
        ),
      ],
    );
  }
}

/// Step 3: new password. Success signs in and every other device is signed
/// out.
class ForgotResetScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ForgotResetScreen> createState() => _ForgotResetScreenState();
}

class _ForgotResetScreenState extends ConsumerState<ForgotResetScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String?> _local = const {};

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = Validators(context.l10n);
    setState(() {
      _local = {
        'password': v.newPassword(_password.text),
        'password_confirmation': v.confirmation(_confirm.text, _password.text),
      };
    });
    if (_local.values.any((e) => e != null)) return;
    FocusScope.of(context).unfocus();
    final toast = context.l10n.passwordChangedToast;
    final ok = await ref
        .read(forgotResetControllerProvider.notifier)
        .reset(password: _password.text, passwordConfirmation: _confirm.text);
    if (ok) {
      showToast(toast);
      // Signed out users are redirected Home by the router; signed-in users
      // (Account → Change password) go back explicitly.
      if (mounted) context.go(Routes.home);
    }
  }

  Future<void> _expired(String message) async {
    await showMessageDialog(
      context,
      title: context.l10n.startAgainTitle,
      message: message,
    );
    ref.read(resetFlowProvider.notifier).clear();
    if (mounted) context.go(Routes.forgot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(forgotResetControllerProvider);
    final controller = ref.read(forgotResetControllerProvider.notifier);

    ref.listen(forgotResetControllerProvider, (_, next) {
      if (next.error case final Validation v) {
        if (v.first('reset_token') case final m?) unawaited(_expired(m));
      }
    });

    String? error(String f) => _local[f] ?? status.field(f);

    return AuthScaffold(
      headline: l10n.newPasswordHeadline,
      showBack: true,
      children: [
        AppTextField(
          label: l10n.newPasswordLabel,
          controller: _password,
          obscure: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          helperText: l10n.passwordHelper,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          errorText: error('password'),
          onChanged: (_) => controller.clearField('password'),
        ),
        const SizedBox(height: Space.x16),
        AppTextField(
          label: l10n.confirmPasswordLabel,
          controller: _confirm,
          obscure: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          errorText: error('password_confirmation'),
          onChanged: (_) => controller.clearField('password_confirmation'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.x24),
        SubmitSection(
          status: status,
          label: l10n.savePasswordButton,
          onPressed: _submit,
        ),
      ],
    );
  }
}
