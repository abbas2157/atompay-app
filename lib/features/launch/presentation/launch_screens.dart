import 'dart:async';

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nucleus background with the logo (handbook §5.2). Also shows the
/// "offline, nothing cached" retry.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(launchControllerProvider) is Launching) {
        unawaited(ref.read(launchControllerProvider.notifier).start());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.stop();
    } else if (!_orbit.isAnimating) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(authControllerProvider) is AuthOffline;
    // Light status-bar icons on the dark splash.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.nucleus,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _orbit,
                  builder: (_, _) => AtomLogo(size: 96, orbit: _orbit.value),
                ),
                if (offline) ...[
                  const SizedBox(height: Space.x32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.x32),
                    child: Text(
                      context.l10n.launchOffline,
                      textAlign: TextAlign.center,
                      style: context.text.body.copyWith(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(height: Space.x16),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                    ),
                    onPressed: () =>
                        ref.read(launchControllerProvider.notifier).start(),
                    child: Text(context.l10n.tryAgain),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking: the app version is below `min_version`.
class UpdateRequiredScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final launch = ref.watch(launchControllerProvider);
    final storeUrl = launch is UpdateRequired ? launch.storeUrl : null;
    final support = ref.watch(appConfigProvider).support;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AtomLogo(size: 72)),
                const SizedBox(height: Space.x24),
                Text(
                  l10n.updateRequired,
                  textAlign: TextAlign.center,
                  style: context.text.title,
                ),
                const SizedBox(height: Space.x32),
                if (storeUrl != null)
                  PrimaryButton(
                    label: l10n.updateButton,
                    onPressed: () => openLink(context, Uri.parse(storeUrl)),
                  )
                else ...[
                  Text(
                    l10n.updateContactSupport,
                    textAlign: TextAlign.center,
                    style: context.text.body,
                  ),
                  const SizedBox(height: Space.x16),
                  if (support.phone case final phone?)
                    GhostButton(
                      label: '${l10n.supportPhone} · $phone',
                      onPressed: () =>
                          openLink(context, Uri(scheme: 'tel', path: phone)),
                    ),
                  if (support.email case final email?) ...[
                    const SizedBox(height: Space.x8),
                    GhostButton(
                      label: '${l10n.supportEmail} · $email',
                      onPressed: () =>
                          openLink(context, Uri(scheme: 'mailto', path: email)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
