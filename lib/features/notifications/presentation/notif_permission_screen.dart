import 'dart:async';

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Turn on notifications" (canvas "NotifPermission"): why, before the
/// system prompt (brief §10). Shown after sign-in, never at launch, and
/// "Not now" never re-asks on every open.
class NotifPermissionScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotifPermissionScreen> createState() =>
      _NotifPermissionScreenState();
}

class _NotifPermissionScreenState extends ConsumerState<NotifPermissionScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(notificationPermissionProvider).request();
    } finally {
      if (mounted) navigator.pop();
    }
  }

  Future<void> _notNow() async {
    final navigator = Navigator.of(context);
    await ref.read(notificationPermissionProvider).dismiss();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.white,
      appBar: AppTopBar(
        title: 'Turn on notifications',
        leading: TopBarLeading.close,
        onLeading: () => unawaited(_notNow()),
        white: true,
        actions: [
          TextLink('Not now', onPressed: () => unawaited(_notNow())),
          const SizedBox(width: Space.s8),
        ],
      ),
      body: FormPage(
        footer: AppButton.primary(
          'Turn on notifications',
          large: true,
          block: true,
          busy: _busy,
          onPressed: () => unawaited(_allow()),
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IconTile(
              Icons.notifications_active_outlined,
              tone: TileTone.amber,
              size: 64,
            ),
          ),
          Gap.s20,
          const PageIntro(
            title: 'Never miss a payment date',
            lead: 'We will only tell you what matters to your plan.',
          ),
          Gap.s20,
          AppCard(
            child: TickList([
              const TextSpan(text: 'Before a payment is due'),
              const TextSpan(text: 'When your limit is decided'),
              TextSpan(
                children: [
                  const TextSpan(text: 'When your order moves '),
                  TextSpan(
                    text: '· approved, delivered, paid',
                    style: TextStyle(color: c.muted),
                  ),
                ],
              ),
            ], icon: Icons.notifications_none),
          ),
          Gap.s16,
          Text(
            'Your inbox in the app shows everything either way. Change this '
            'any time in Account.',
            style: t.small,
          ),
        ],
      ),
    );
  }
}

/// Shows the explainer once, after sign-in, when push is live on both the
/// server (`features.push`) and the app ([PushSupport.ready]) and the
/// customer hasn't been asked or said "Not now".
Future<void> maybeAskForNotifications(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_shownThisSession) return;
  if (!PushSupport.ready || !ref.read(appConfigProvider).features.push) return;
  final permission = ref.read(notificationPermissionProvider);
  if (permission.dismissed) return;
  if (await permission.status() != PermissionView.notAsked) return;
  if (!context.mounted) return;
  _shownThisSession = true;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const NotifPermissionScreen(),
    ),
  );
}

bool _shownThisSession = false;
