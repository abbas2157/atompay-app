import 'dart:async';

import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:atompay_mobile/core/security/app_lock.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme and language for everyone; biometric unlock once signed in.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    unawaited(_checkBiometrics());
  }

  Future<void> _checkBiometrics() async {
    final ok = await ref.read(biometricServiceProvider).isAvailable();
    if (mounted) setState(() => _biometricAvailable = ok);
  }

  Future<void> _toggleBiometric({required bool enabled}) async {
    final l10n = context.l10n;
    final settings = ref.read(appSettingsProvider.notifier);
    if (!enabled) {
      await settings.setBiometricLock(enabled: false);
      return;
    }
    // Prove it works before relying on it, so nobody locks themselves out.
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(l10n.unlockReason);
    if (ok) await settings.setBiometricLock(enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final settings = ref.watch(appSettingsProvider);
    final signedIn = ref.watch(authControllerProvider) is SignedIn;

    Widget heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x16,
        Space.gutter,
        Space.x8,
      ),
      child: Text(title.toUpperCase(), style: text.eyebrow),
    );

    Widget choices<T>(
      List<(T, String)> options,
      T selected,
      void Function(T) on,
    ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Wrap(
        spacing: Space.x8,
        runSpacing: Space.x8,
        children: [
          for (final (value, label) in options)
            ChoiceChip(
              label: Text(label),
              selected: value == selected,
              selectedColor: AppColors.violet.withValues(alpha: 0.16),
              checkmarkColor: AppColors.violet,
              labelStyle: text.label.copyWith(
                color: value == selected
                    ? AppColors.violet
                    : context.tokens.ink,
              ),
              onSelected: (_) => on(value),
            ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.x24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(l10n.settingsTitle, style: text.headline),
            ),
            heading(l10n.languageTitle),
            choices<String?>(
              [(null, l10n.matchPhone), ('en', 'English'), ('ur', 'اردو')],
              settings.localeCode,
              (code) => unawaited(
                ref.read(appSettingsProvider.notifier).setLocale(code),
              ),
            ),
            heading(l10n.appearanceTitle),
            choices<ThemeMode>(
              [
                (ThemeMode.system, l10n.matchPhone),
                (ThemeMode.light, l10n.themeLight),
                (ThemeMode.dark, l10n.themeDark),
              ],
              settings.themeMode,
              (mode) => unawaited(
                ref.read(appSettingsProvider.notifier).setThemeMode(mode),
              ),
            ),
            if (signedIn) ...[
              heading(l10n.securityTitle),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.gutter,
                ),
                title: Text(l10n.biometricLock),
                subtitle: Text(
                  _biometricAvailable == false
                      ? l10n.biometricUnavailable
                      : l10n.biometricLockHelp,
                ),
                value: settings.biometricLock,
                onChanged: _biometricAvailable == true
                    ? (v) => unawaited(_toggleBiometric(enabled: v))
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
