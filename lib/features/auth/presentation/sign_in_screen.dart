import 'dart:async';

import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/application/auth_forms.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
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
    final t = context.text;
    final offline = ref.watch(isOfflineProvider);
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
          child: FormPage(
            children: [
              const PageIntro(
                eyebrow: 'Welcome back',
                title: 'Sign in with your AtomShop account',
                lead:
                    'The same email or mobile and password you use on '
                    'Atomshop.pk.',
              ),
              Gap.s24,
              AppTextField(
                label: 'Email or mobile number',
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
              Gap.s14,
              PasswordField(
                label: 'Password',
                controller: _password,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                error: status.field('password'),
                onChanged: (_) => ref
                    .read(signInFormProvider.notifier)
                    .clearField('password'),
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextLink(
                  'Forgot password?',
                  onPressed: () => context.pushOnce(Routes.forgot),
                ),
              ),
              Gap.s12,
              SubmitSection(
                label: 'Sign in',
                status: status,
                offline: offline,
                fieldsOnScreen: const {'login', 'password'},
                onSubmit: _submit,
                onRetryReady: () => setState(() {}),
              ),
              Gap.s16,
              const Note(
                tone: NoteTone.wash,
                text:
                    'AtomPay is offered on eligible products: always 3 '
                    'months, no advance, 0% markup. A 3% processing fee is '
                    'shown with every plan, and delivery charges apply.',
              ),
              Gap.s16,
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New to AtomPay? ', style: t.small),
                  TextLink(
                    'Create an account',
                    onPressed: () => context.go(Routes.register),
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
