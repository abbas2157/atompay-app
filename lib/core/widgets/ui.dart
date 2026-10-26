import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// For snackbars that must survive a route change (e.g. after password reset).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Text for a non-field error. Server messages are written for customers and
/// shown as-is (handbook §4.7); transport failures get our own wording.
String apiErrorText(AppLocalizations l10n, ApiException e) => switch (e) {
  NetworkError() => l10n.networkError,
  ServerError() || UnexpectedError() => l10n.genericError,
  NotFound() => l10n.notFound,
  RateLimited() => l10n.genericError,
  _ => e.message.isEmpty ? l10n.genericError : e.message,
};

void showToast(String message) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.ok),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: context.tokens.ink),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.coral)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Links come from `/app-config` and plan data, so only these schemes open;
/// anything else (`intent:`, `file:`, `javascript:`…) is refused.
const _openableSchemes = {'https', 'tel', 'mailto'};

Future<void> openLink(BuildContext context, Uri uri) async {
  final failed = context.l10n.couldNotOpenLink;
  final ok =
      _openableSchemes.contains(uri.scheme.toLowerCase()) &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) showToast(failed);
}

/// Logo, headline, optional intro, then a scrolling form in the gutter.
class AuthScaffold extends StatelessWidget {
  const new({
    required this.headline,
    required this.children,
    super.key,
    this.intro,
    this.showBack = false,
  });

  final String headline;
  final String? intro;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // No app bar to set it when [showBack] is false: match the theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: showBack ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x24,
                    Space.gutter,
                    Space.x40,
                  ),
                  children: [
                    if (!showBack) ...[
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AtomLogo(size: 48),
                      ),
                      const SizedBox(height: Space.x24),
                    ],
                    Text(headline, style: text.headline),
                    if (intro != null) ...[
                      const SizedBox(height: Space.x8),
                      Text(intro!, style: text.body),
                    ],
                    const SizedBox(height: Space.x24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Coral message line for a non-field error, or the `429` countdown.
class FormErrorText extends StatelessWidget {
  const new(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: context.text.bodySmall.copyWith(color: AppColors.coral),
        ),
      ),
    );
  }
}
