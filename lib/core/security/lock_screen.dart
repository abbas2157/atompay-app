import 'dart:async';

import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:atompay_mobile/core/security/app_lock.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Covers the app while biometric lock is on and the customer is signed in.
/// Also tracks backgrounding so a long absence locks again.
class AppLockGate extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  /// Not in the foreground: the app-switcher snapshot is taken now.
  bool _away = false;

  /// What the Android recents thumbnail was last set to.
  bool _recentsHidden = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(appLockProvider.notifier).backgrounded(),
      onShow: () => ref.read(appLockProvider.notifier).resumed(),
      onStateChange: (state) {
        final away = state != AppLifecycleState.resumed;
        if (away != _away && mounted) setState(() => _away = away);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _syncRecents({required bool hidden}) {
    if (hidden == _recentsHidden) return;
    _recentsHidden = hidden;
    unawaited(SecureScreen.setRecentsHidden(hidden: hidden));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider) is SignedIn;
    final lockOn = signedIn && ref.watch(appSettingsProvider).biometricLock;
    final locked = signedIn && ref.watch(appLockProvider);
    _syncRecents(hidden: lockOn);
    return Stack(
      children: [
        // The app stays mounted under the lock, so keep screen readers and
        // keyboards out of it: their actions skip the hit test.
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(excluding: locked, child: widget.child),
        ),
        if (locked) const Positioned.fill(child: _LockScreen()),
        // Balances shouldn't show in the app switcher either.
        if (lockOn && !locked && _away)
          Positioned.fill(
            child: ColoredBox(
              color: context.tokens.paper,
              child: const Center(child: AtomLogo(size: 64)),
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prompt straight away; the button is there if they cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(context.l10n.unlockReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) ref.read(appLockProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.tokens.paper,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AtomLogo(size: 72)),
              const SizedBox(height: Space.x24),
              Text(
                l10n.unlockTitle,
                textAlign: TextAlign.center,
                style: context.text.headline,
              ),
              const SizedBox(height: Space.x32),
              PrimaryButton(
                label: l10n.unlockButton,
                loading: _busy,
                onPressed: () => unawaited(_unlock()),
              ),
              const SizedBox(height: Space.x12),
              // Fallback when biometrics stop working: sign in again.
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        ref.read(appLockProvider.notifier).unlock();
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                      },
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
