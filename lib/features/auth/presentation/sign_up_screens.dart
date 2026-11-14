import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
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

/// Sign up, step 1: name, email or mobile, password (canvas "Sign up").
class SignUpScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  late final TextEditingController _name;
  late final TextEditingController _login;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focus = {
    'name': FocusNode(),
    'login': FocusNode(),
    'password': FocusNode(),
    'password_confirmation': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    // Coming back from the code screen keeps what was typed.
    final draft = ref.read(signupFlowProvider);
    _name = TextEditingController(text: draft.name);
    _login = TextEditingController(text: draft.login);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reason = ref.read(signupFlowProvider).restartReason;
      if (reason != null && mounted) showToast(reason, error: true);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _login, _password, _confirm]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _name.text.isNotEmpty ||
      _login.text.isNotEmpty ||
      _password.text.isNotEmpty;

  Future<void> _submit() async {
    final form = ref.read(signUpFormProvider.notifier);
    final emailOnly = !ref
        .read(appConfigProvider)
        .features
        .signupChannels
        .contains('whatsapp');
    final login = _login.text.trim();
    final errors = <String, String>{
      if (_name.text.trim().isEmpty) 'name': 'Enter your full name.',
      if (login.isEmpty)
        'login': emailOnly
            ? 'Enter your email address.'
            : 'Enter your email or mobile number.'
      else if (emailOnly && !Pk.isEmail(login))
        'login': 'Enter your email address.',
      'password': ?AuthChecks.password(_password.text),
      'password_confirmation': ?AuthChecks.confirmation(
        _password.text,
        _confirm.text,
      ),
    };
    if (errors.isNotEmpty) {
      form.fail(errors);
      focusFirstError(ref.read(signUpFormProvider), _focus);
      return;
    }
    final ok = await form.submit(
      name: _name.text.trim(),
      login: login,
      password: _password.text,
      confirmation: _confirm.text,
    );
    if (!mounted) return;
    if (ok) {
      await context.push(Routes.registerVerify);
    } else {
      focusFirstError(ref.read(signUpFormProvider), _focus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(signUpFormProvider);
    final form = ref.read(signUpFormProvider.notifier);
    final emailOnly = !ref
        .watch(appConfigProvider)
        .features
        .signupChannels
        .contains('whatsapp');
    final t = context.text;
    return FormExitGuard(
      dirty: _dirty,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.white,
        appBar: AppTopBar(
          white: true,
          onLeading: () => Navigator.of(context).maybePop().then((popped) {
            if (!popped && context.mounted) context.go(Routes.welcome);
          }),
        ),
        body: AutofillGroup(
          child: AuthPage(
            bottom: AuthFooterLink(
              lead: 'Already have an account? ',
              link: 'Sign in',
              onPressed: () => context.go(Routes.login),
            ),
            children: [
              // One stop for a screen reader; the heading below names the
              // page, so the lockup itself stays decorative.
              Semantics(
                container: true,
                label: 'AtomPay',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      const AtomPayMark(size: 52),
                      const SizedBox(width: Space.s14),
                      Text(
                        'AtomPay',
                        style: t.h4.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              AuthGap.form,
              PageIntro(
                eyebrow: 'Create an account',
                title: 'Start with your name',
                lead: emailOnly
                    ? 'Sign up with your email and we email you a code.'
                    : 'Sign up with your email and we email you a code, or '
                          'with your mobile number and we send it on '
                          'WhatsApp.',
              ),
              AuthGap.form,
              AppTextField(
                label: 'Full name',
                placeholder: 'Ali Raza',
                controller: _name,
                focusNode: _focus['name'],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                error: status.field('name'),
                onChanged: (_) {
                  form.clearField('name');
                  setState(() {});
                },
              ),
              AuthGap.field,
              AppTextField(
                label: emailOnly ? 'Email address' : 'Email or mobile number',
                placeholder: emailOnly
                    ? 'you@example.com'
                    : 'you@example.com or 0300 1234567',
                controller: _login,
                focusNode: _focus['login'],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                hint: emailOnly
                    ? null
                    : 'A mobile number gets its code on WhatsApp.',
                error: status.field('login'),
                onChanged: (_) {
                  form.clearField('login');
                  setState(() {});
                },
              ),
              AuthGap.field,
              PasswordField(
                label: 'Password',
                placeholder: 'Create a password',
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
              PasswordField(
                label: 'Confirm password',
                placeholder: 'Re-enter your password',
                controller: _confirm,
                focusNode: _focus['password_confirmation'],
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                error: status.field('password_confirmation'),
                onChanged: (_) => form.clearField('password_confirmation'),
                onSubmitted: (_) => _submit(),
              ),
              AuthGap.field,
              Text(
                'At least 8 characters. This also creates your '
                'AtomShop.pk account.',
                style: t.tiny,
              ),
              AuthGap.form,
              SubmitSection(
                label: 'Send my code',
                status: status,
                offline: ref.watch(isOfflineProvider),
                fieldsOnScreen: _focus.keys.toSet(),
                onSubmit: _submit,
                onRetryReady: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign up, step 2: the 6-digit code (canvas "Verify code").
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(verifySignupFormProvider.notifier);
    if (!AuthChecks.isValidCode(_code.text)) {
      form.fail({'code': 'Enter the 6-digit code.'});
      return;
    }
    final outcome = await form.submit(_code.text);
    if (!mounted) return;
    if (outcome == VerifyOutcome.restart) {
      context.pop();
    } else if (outcome == VerifyOutcome.wrongCode) {
      _code.clear();
    }
    // Signed in: the router moves on to Home.
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(signupFlowProvider);
    final status = ref.watch(verifySignupFormProvider);
    final sent = draft.sent;
    final t = context.text;
    if (sent == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
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
              eyebrow: 'Almost there',
              title: 'Enter your code',
              leadSpans: [
                TextSpan(
                  text: byWhatsApp
                      ? 'We sent a 6-digit code on WhatsApp to '
                      : 'We emailed a 6-digit code to ',
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
              error: status.field('code'),
              onChanged: (_) => ref
                  .read(verifySignupFormProvider.notifier)
                  .clearField('code'),
              onCompleted: (_) => _submit(),
            ),
            AuthGap.code,
            SubmitSection(
              label: 'Verify and continue',
              status: status,
              offline: ref.watch(isOfflineProvider),
              fieldsOnScreen: const {'code', 'signup'},
              onSubmit: _submit,
              onRetryReady: () => setState(() {}),
            ),
            AuthGap.code,
            ResendRow(
              sentAt: draft.sentAt,
              resendIn: sent.resendIn,
              busy: status.busy,
              onResend: () =>
                  ref.read(verifySignupFormProvider.notifier).resend(),
            ),
            // 24 to the text: the link's 48 dp target adds ~14 above it.
            Gap.s10,
            Center(
              child: TextLink(
                byWhatsApp ? 'Use a different number' : 'Use a different email',
                onPressed: () => context.pop(),
                style: t.small.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
