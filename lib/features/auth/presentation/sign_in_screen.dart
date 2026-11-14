import 'dart:async';

import 'package:atompay_mobile/core/router/navigation.dart';
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
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/presentation/code_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign in with the AtomShop account (canvas "Sign in").
class SignInScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _loginFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showReason());
  }

  /// "You've been signed out" after a 401, or the 403's message.
  Future<void> _showReason() async {
    final s = ref.read(sessionProvider);
    if (s is! SignedOut || s.reason == null || !mounted) return;
    ref.read(sessionProvider.notifier).consumeReason();
    final is401 = s.reason == "You've been signed out";
    await showAppDialog(
      context: context,
      title: is401 ? "You've been signed out" : "Can't sign in here",
      body: is401 ? 'For your security, please sign in again.' : s.reason,
      confirm: is401 ? 'Sign in' : 'OK',
    );
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(signInFormProvider.notifier);
    final login = _login.text.trim();
    if (login.isEmpty || _password.text.isEmpty) {
      form.fail({
        if (login.isEmpty) 'login': 'Enter your email or mobile number.',
        if (_password.text.isEmpty) 'password': 'Enter your password.',
      });
      focusFirstError(ref.read(signInFormProvider), {
        'login': _loginFocus,
        'password': _passwordFocus,
      });
      return;
    }
    TextInput.finishAutofillContext();
    final ok = await form.submit(login: login, password: _password.text);
    if (!ok && mounted) {
      focusFirstError(ref.read(signInFormProvider), {
        'login': _loginFocus,
        'password': _passwordFocus,
      });
    }
    // On success the router's guard moves on (to `from`, or Home).
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(signInFormProvider);
    final offline = ref.watch(isOfflineProvider);
    final t = context.text;
    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.white,
        appBar: AppTopBar(
          white: true,
          onLeading: () =>
              context.canPop() ? context.pop() : context.go(Routes.welcome),
        ),
        body: AutofillGroup(
          child: AuthPage(
            bottom: AuthFooterLink(
              lead: 'New to AtomPay? ',
              link: 'Create an account',
              onPressed: () => context.go(Routes.register),
            ),
            children: [
              // One stop for a screen reader; the heading names the page.
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
              const PageIntro(
                eyebrow: 'Welcome back',
                title: 'Sign in with your AtomShop account',
                lead:
                    'The same email or mobile and password you use on '
                    'Atomshop.pk.',
              ),
              AuthGap.form,
              AppTextField(
                label: 'Email or mobile number',
                placeholder: 'you@example.com or 0300 1234567',
                controller: _login,
                focusNode: _loginFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
                hint: 'A mobile number signs you in the same as your email.',
                error: status.field('login'),
                onChanged: (_) =>
                    ref.read(signInFormProvider.notifier).clearField('login'),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              AuthGap.field,
              PasswordField(
                label: 'Password',
                placeholder: 'Your password',
                controller: _password,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                error: status.field('password'),
                onChanged: (_) => ref
                    .read(signInFormProvider.notifier)
                    .clearField('password'),
                onSubmitted: (_) => _submit(),
              ),
              AuthGap.field,
              Align(
                alignment: Alignment.centerRight,
                child: TextLink(
                  'Forgot password?',
                  onPressed: () => context.pushOnce(Routes.forgot),
                ),
              ),
              AuthGap.form,
              SubmitSection(
                label: 'Sign in',
                status: status,
                offline: offline,
                fieldsOnScreen: const {'login', 'password'},
                onSubmit: _submit,
                onRetryReady: () => setState(() {}),
              ),
              AuthGap.form,
              const Note(
                tone: NoteTone.wash,
                icon: Icons.shield_outlined,
                spans: [
                  TextSpan(
                    text:
                        'AtomPay is offered on eligible products: always 3 '
                        'months, no advance, 0% markup. A 3% processing fee '
                        'is shown with every plan, and delivery charges '
                        'apply.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
