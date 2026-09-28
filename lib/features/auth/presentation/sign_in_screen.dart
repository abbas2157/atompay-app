import 'dart:async';

import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/forms/validators.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/auth/domain/auth_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  Map<String, String?> _local = const {};

  @override
  void initState() {
    super.initState();
    // A 403 that ended the previous session (handbook §3.4).
    WidgetsBinding.instance.addPostFrameCallback((_) => _showEndedMessage());
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _showEndedMessage() async {
    final auth = ref.read(authControllerProvider);
    if (auth case SignedOut(message: final m?) when m.isNotEmpty && mounted) {
      ref.read(authControllerProvider.notifier).clearMessage();
      await showMessageDialog(
        context,
        title: context.l10n.signInBlockedTitle,
        message: m,
      );
    }
  }

  Future<void> _submit() async {
    final v = Validators(context.l10n);
    setState(() {
      _local = {
        'login': v.login(_login.text),
        'password': v.required(_password.text),
      };
    });
    if (_local.values.any((e) => e != null)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(signInControllerProvider.notifier)
        .submit(login: _login.text, password: _password.text);
    // Success: the router leaves this screen when auth state changes.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);

    ref.listen(signInControllerProvider, (_, next) {
      if (next.error case final Forbidden f) {
        controller.clearError();
        unawaited(
          showMessageDialog(
            context,
            title: l10n.signInBlockedTitle,
            message: f.message,
          ),
        );
      }
    });

    return AuthScaffold(
      // Opened from the guest tray: offer the way back.
      showBack: context.canPop(),
      headline: l10n.signInHeadline,
      intro: l10n.signInTitle,
      children: [
        LoginField(
          label: l10n.loginLabel,
          hintText: l10n.loginHint,
          controller: _login,
          errorText: _local['login'] ?? status.field('login'),
          onChanged: (_) {
            controller.clearField('login');
            if (_local['login'] != null) setState(() => _local = const {});
          },
        ),
        const SizedBox(height: Space.x16),
        AppTextField(
          label: l10n.passwordLabel,
          controller: _password,
          obscure: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          errorText: _local['password'] ?? status.field('password'),
          onChanged: (_) => controller.clearField('password'),
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => context.push(Routes.forgot),
            child: Text(l10n.forgotPasswordLink),
          ),
        ),
        const SizedBox(height: Space.x8),
        SubmitSection(
          status: status,
          label: l10n.signInButton,
          onPressed: _submit,
        ),
        const SizedBox(height: Space.x24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.noAccountPrompt, style: context.text.bodySmall),
            TextButton(
              onPressed: () => context.push(Routes.register),
              child: Text(l10n.createAccountLink),
            ),
          ],
        ),
        // Public tools, usable before signing up.
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push(Routes.estimate),
              child: Text(l10n.estimatorLink),
            ),
            TextButton(
              onPressed: () => context.push(Routes.calculator),
              child: Text(l10n.calculatorTitle),
            ),
          ],
        ),
      ],
    );
  }
}
