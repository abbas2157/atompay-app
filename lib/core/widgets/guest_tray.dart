import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The bottom tray on every guest screen: "Create account" and "Sign in",
/// always one tap away. Renders nothing once signed in, so public screens
/// (calculator, estimator) can include it unconditionally.
class GuestTray extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authControllerProvider) is SignedIn) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final t = context.tokens;
    return Material(
      color: t.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x12,
              Space.gutter,
              Space.x12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.trayPrompt,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Space.x8),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: l10n.signInButton,
                        onPressed: () => context.push(Routes.login),
                      ),
                    ),
                    const SizedBox(width: Space.x12),
                    Expanded(
                      child: PrimaryButton(
                        label: l10n.createAccountLink,
                        onPressed: () => context.push(Routes.register),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
