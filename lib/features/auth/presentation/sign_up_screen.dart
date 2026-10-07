import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/forms/validators.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_flows.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign-up screen 1: name, one contact, password (handbook §5.4). The code
/// screen is pushed on top, so these values survive coming back.
class SignUpScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String?> _local = const {};

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailOnly => !ref.read(appConfigProvider).features.signupByWhatsapp;

  Future<void> _submit() async {
    final v = Validators(context.l10n);
    setState(() {
      _local = {
        'name': v.required(_name.text),
        'login': v.login(_login.text, emailOnly: _emailOnly),
        'password': v.newPassword(_password.text),
        'password_confirmation': v.confirmation(_confirm.text, _password.text),
      };
    });
    if (_local.values.any((e) => e != null)) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(signUpControllerProvider.notifier)
        .submit(
          name: _name.text,
          login: _login.text,
          password: _password.text,
          passwordConfirmation: _confirm.text,
        );
    if (ok && mounted) await context.push(Routes.registerVerify);
  }

  String? _error(String field) =>
      _local[field] ?? ref.read(signUpControllerProvider).field(field);

  void _edited(String field) {
    ref.read(signUpControllerProvider.notifier).clearField(field);
    if (_local[field] != null) {
      setState(() => _local = {..._local, field: null});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(signUpControllerProvider);
    final emailOnly = !ref.watch(appConfigProvider).features.signupByWhatsapp;

    return AuthScaffold(
      headline: l10n.signUpHeadline,
      showBack: true,
      children: [
        AppTextField(
          label: l10n.fullNameLabel,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          errorText: _error('name'),
          onChanged: (_) => _edited('name'),
        ),
        const SizedBox(height: Space.x16),
        LoginField(
          label: emailOnly ? l10n.emailLabel : l10n.loginLabel,
          hintText: emailOnly ? l10n.emailHint : l10n.loginHint,
          controller: _login,
          emailOnly: emailOnly,
          errorText: _error('login'),
          helperFor: (value) {
            final t = value.trim();
            if (t.isEmpty) return null;
            if (t.contains('@')) return l10n.hintCodeByEmail;
            if (!emailOnly && Pk.looksLikeMobile(t)) {
              return l10n.hintCodeByWhatsapp;
            }
            return null;
          },
          onChanged: (_) => _edited('login'),
        ),
        const SizedBox(height: Space.x16),
        AppTextField(
          label: l10n.passwordLabel,
          controller: _password,
          obscure: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          helperText: l10n.passwordHelper,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          errorText: _error('password'),
          onChanged: (_) => _edited('password'),
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
          errorText: _error('password_confirmation'),
          onChanged: (_) => _edited('password_confirmation'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.x16),
        Text(l10n.signUpSmallPrint, style: context.text.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => openLink(
              context,
              Uri.parse(ref.read(appConfigProvider).privacyUrl),
            ),
            child: Text(l10n.privacyPolicy),
          ),
        ),
        const SizedBox(height: Space.x8),
        SubmitSection(
          status: status,
          label: l10n.sendCodeButton,
          onPressed: _submit,
        ),
        const SizedBox(height: Space.x24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.haveAccountPrompt, style: context.text.bodySmall),
            TextButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.login),
              child: Text(l10n.signInButton),
            ),
          ],
        ),
      ],
    );
  }
}
