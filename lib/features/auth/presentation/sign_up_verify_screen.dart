import 'dart:async';

import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/widgets/otp_field.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/domain/auth_flows.dart';
import 'package:atompay_mobile/features/auth/presentation/code_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign-up screen 2 (handbook §5.4).
class SignUpVerifyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignUpVerifyScreen> createState() => _SignUpVerifyScreenState();
}

class _SignUpVerifyScreenState extends ConsumerState<SignUpVerifyScreen> {
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
    await ref.read(signUpVerifyControllerProvider.notifier).verify(_code.text);
    // Success: signed in, and the router moves to Home.
  }

  Future<void> _resend() async {
    final ok = await ref.read(signUpVerifyControllerProvider.notifier).resend();
    if (ok && mounted) {
      _code.clear();
      showToast(context.l10n.codeResent);
    }
  }

  /// `errors.signup`: expired, too many wrong codes, or the contact was taken
  /// meanwhile. Always back to the details screen.
  Future<void> _restart(String message) async {
    await showMessageDialog(
      context,
      title: context.l10n.startAgainTitle,
      message: message,
    );
    ref.read(pendingSignupProvider.notifier).clear();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = ref.watch(pendingSignupProvider);
    final status = ref.watch(signUpVerifyControllerProvider);

    ref.listen(signUpVerifyControllerProvider, (_, next) {
      if (next.error case final Validation v) {
        if (v.first('signup') case final m?) {
          unawaited(_restart(m));
        } else if (v.first('code') != null) {
          _code.clear();
        }
      }
    });

    if (pending == null) {
      // Opened without a sign-up in memory (e.g. after the app was killed).
      return AuthScaffold(
        headline: l10n.startAgainTitle,
        showBack: true,
        children: const [],
      );
    }

    final c = pending.challenge;
    final sentTo = switch (c.channel) {
      CodeChannel.email => l10n.codeSentByEmail(c.destination),
      CodeChannel.whatsapp => l10n.codeSentByWhatsapp(c.destination),
      CodeChannel.unknown => l10n.codeSentTo(c.destination),
    };

    return AuthScaffold(
      headline: l10n.enterCodeHeadline,
      showBack: true,
      children: [
        CodeEntry(
          sentTo: sentTo,
          code: _code,
          status: status,
          codeError: _local ?? status.field('code'),
          resendAt: pending.resendAt,
          submitLabel: l10n.createAccountButton,
          onSubmit: _verify,
          onResend: _resend,
        ),
      ],
    );
  }
}
