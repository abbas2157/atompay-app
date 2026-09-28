import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/security/lock_screen.dart';
import 'package:atompay_mobile/core/theme/app_theme.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AtomPayApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: rootMessengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: !Env.isProd,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      // Null follows the phone; Urdu lays everything out right-to-left.
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          AppLockGate(child: _ScriptTypography(child: child!)),
    );
  }
}

/// Letter-spacing and the mono face suit Latin labels but break joined
/// scripts like Urdu, so right-to-left locales get them without.
class _ScriptTypography extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Directionality.of(context) != TextDirection.rtl) return child;
    final theme = Theme.of(context);
    final text = theme.extension<AppText>()!;
    return Theme(
      data: theme.copyWith(
        extensions: [
          theme.extension<AppTokens>()!,
          text.copyWith(
            display: text.display.copyWith(letterSpacing: 0),
            eyebrow: text.eyebrow.copyWith(
              letterSpacing: 0,
              fontSize: 12,
              fontFamily: FontFamilies.body,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}
