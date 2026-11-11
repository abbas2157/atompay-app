import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/application/auth_forms.dart';
import 'package:atompay_mobile/features/auth/presentation/code_widgets.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Forgot password 1: email or mobile. The next screen never says whether
/// an account exists.
class ForgotScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  late final TextEditingController _login = TextEditingController(
    text: ref.read(resetFlowProvider).login,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reason = ref.read(resetFlowProvider).restartReason;
      if (reason != null && mounted) showToast(reason, error: true);
    });
  }

  @override
  void dispose() {
    _login.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(forgotFormProvider.notifier);
    final emailOnly = !ref
        .read(appConfigProvider)
        .features
        .passwordResetChannels
        .contains('whatsapp');
    final login = _login.text.trim();
    if (login.isEmpty || (emailOnly && !Pk.isEmail(login))) {
      form.fail({
        'login': emailOnly
            ? 'Enter your email address.'
            : 'Enter your email or mobile number.',
      });
      _focus.requestFocus();
      return;
    }
    if (await form.send(login) && mounted) {
      await context.push(Routes.forgotVerify);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(forgotFormProvider);
    final emailOnly = !ref
        .watch(appConfigProvider)
        .features
        .passwordResetChannels
        .contains('whatsapp');
    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.white,
        appBar: const AppTopBar(white: true),
        body: AuthPage(
          children: [
            PageIntro(
              eyebrow: 'Forgot password',
              title: 'Reset your password',
              lead: emailOnly
                  ? 'Enter the email address on your AtomShop account.'
                  : 'Enter the email or mobile number on your AtomShop '
                        'account.',
            ),
            AuthGap.form,
            AppTextField(
              label: emailOnly ? 'Email address' : 'Email or mobile number',
              controller: _login,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              hint: emailOnly
                  ? null
                  : 'Mobile numbers get the code on WhatsApp.',
              error: status.field('login'),
              onChanged: (_) =>
                  ref.read(forgotFormProvider.notifier).clearField('login'),
              onSubmitted: (_) => _submit(),
            ),
            AuthGap.form,
            SubmitSection(
              label: 'Send code',
              status: status,
              offline: ref.watch(isOfflineProvider),
              fieldsOnScreen: const {'login'},
              onSubmit: _submit,
              onRetryReady: () => setState(() {}),
            ),
            AuthGap.form,
            const Note(
              tone: NoteTone.blue,
              text:
                  'This changes your AtomShop.pk password too — it is one '
                  'account.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Forgot password 2: the code.
class ForgotCodeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ForgotCodeScreen> createState() => _ForgotCodeScreenState();
}

class _ForgotCodeScreenState extends ConsumerState<ForgotCodeScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(forgotCodeFormProvider.notifier);
    if (!AuthChecks.isValidCode(_code.text)) {
      form.fail({'code': 'Enter the 6-digit code.'});
      return;
    }
    final outcome = await form.verify(_code.text);
    if (!mounted) return;
    switch (outcome) {
      case VerifyOutcome.signedIn:
        await context.push(Routes.forgotReset);
      case VerifyOutcome.restart:
        context.pop();
      case VerifyOutcome.wrongCode:
        _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(resetFlowProvider);
    final status = ref.watch(forgotCodeFormProvider);
    final sent = draft.sent;
    if (sent == null) return const Scaffold(body: SizedBox.shrink());
    final byWhatsApp = sent.channel == 'whatsapp';
    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.white,
        appBar: const AppTopBar(white: true),
        body: AuthPage(
          children: [
            PageIntro(
              eyebrow: 'Forgot password',
              title: byWhatsApp ? 'Check your WhatsApp' : 'Check your email',
              leadSpans: [
                const TextSpan(
                  text:
                      "If this belongs to an AtomShop account, we've sent a "
                      'code to ',
                ),
                TextSpan(
                  text: sent.destination,
                  style: TextStyle(
                    color: context.colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            AuthGap.code,
            OtpField(
              controller: _code,
              label: 'Reset code',
              // The canvas shows no hint under the reset code.
              hint: null,
              error: status.field('code'),
              onChanged: (_) =>
                  ref.read(forgotCodeFormProvider.notifier).clearField('code'),
              onCompleted: (_) => _submit(),
            ),
            AuthGap.code,
            SubmitSection(
              label: 'Continue',
              status: status,
              offline: ref.watch(isOfflineProvider),
              fieldsOnScreen: const {'code'},
              onSubmit: _submit,
              onRetryReady: () => setState(() {}),
            ),
            AuthGap.code,
            ResendRow(
              sentAt: draft.sentAt,
              resendIn: sent.resendIn,
              busy: status.busy,
              waitingText: 'Send a new code in',
              actionText: 'Send a new code',
              onResend: () =>
                  ref.read(forgotCodeFormProvider.notifier).resend(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forgot password 3: the new password. Success signs in here and out
/// everywhere else, then lands on Home.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focus = {
    'password': FocusNode(),
    'password_confirmation': FocusNode(),
  };

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(newPasswordFormProvider.notifier);
    final errors = <String, String>{
      'password': ?AuthChecks.password(_password.text),
      'password_confirmation': ?AuthChecks.confirmation(
        _password.text,
        _confirm.text,
      ),
    };
    if (errors.isNotEmpty) {
      form.fail(errors);
      focusFirstError(ref.read(newPasswordFormProvider), _focus);
      return;
    }
    final outcome = await form.submit(
      password: _password.text,
      confirmation: _confirm.text,
    );
    if (!mounted) return;
    if (outcome == VerifyOutcome.restart) {
      context.go(Routes.forgot);
    }
    // Signed in: the router lands on Home.
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(newPasswordFormProvider);
    final form = ref.read(newPasswordFormProvider.notifier);
    return FormExitGuard(
      dirty: _password.text.isNotEmpty,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.white,
        appBar: const AppTopBar(white: true),
        body: AuthPage(
          children: [
            const PageIntro(
              eyebrow: 'Forgot password',
              title: 'Choose a new password',
              lead: 'At least 8 characters.',
            ),
            AuthGap.form,
            PasswordField(
              label: 'New password',
              controller: _password,
              focusNode: _focus['password'],
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              error: status.field('password'),
              onChanged: (_) {
                form.clearField('password');
                setState(() {});
              },
            ),
            AuthGap.field,
            AppTextField(
              label: 'Confirm new password',
              controller: _confirm,
              focusNode: _focus['password_confirmation'],
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              error: status.field('password_confirmation'),
              onChanged: (_) => form.clearField('password_confirmation'),
              onSubmitted: (_) => _submit(),
            ),
            AuthGap.form,
            SubmitSection(
              label: 'Set new password',
              status: status,
              offline: ref.watch(isOfflineProvider),
              fieldsOnScreen: const {'password', 'password_confirmation'},
              onSubmit: _submit,
              onRetryReady: () => setState(() {}),
            ),
            AuthGap.form,
            const Note(
              tone: NoteTone.blue,
              icon: Icons.smartphone_outlined,
              text:
                  "You'll stay signed in here and be signed out on every "
                  'other device, on AtomPay and AtomShop.pk.',
            ),
          ],
        ),
      ),
    );
  }
}
