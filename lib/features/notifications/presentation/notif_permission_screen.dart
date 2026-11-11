import 'dart:async';
import 'dart:math' as math;

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/notifications/application/push_controller.dart';
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
      // Allowed: register this phone for push straight away.
      unawaited(ref.read(pushControllerProvider).syncRegistration());
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
    final ink = TextStyle(color: c.ink, fontWeight: FontWeight.w700);
    final reasons = <(IconData, Color, List<InlineSpan>)>[
      (
        Icons.schedule,
        c.amberInk,
        [TextSpan(text: 'Before a payment is due', style: ink)],
      ),
      (
        Icons.star_border,
        c.rose,
        [TextSpan(text: 'When your limit is decided', style: ink)],
      ),
      (
        Icons.local_shipping_outlined,
        c.primary,
        [
          TextSpan(text: 'When your order moves', style: ink),
          const TextSpan(text: ' — approved, delivered, paid'),
        ],
      ),
    ];
    return Scaffold(
      backgroundColor: c.white,
      // Canvas: no title and no close, only "Not now" at the right.
      appBar: AppTopBar(
        leading: null,
        white: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.s14),
            child: TextLink(
              'Not now',
              onPressed: () => unawaited(_notNow()),
              style: t.button.copyWith(color: c.body),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(Space.gutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, box.maxHeight - Space.gutter * 2),
                  ),
                  // Canvas `.content{justify-content:center;gap:22px}`.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: c.primarySoft,
                                borderRadius: BorderRadius.circular(Radii.card),
                              ),
                              child: Icon(
                                Icons.notifications_none,
                                size: 36,
                                color: c.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.s22),
                          Semantics(
                            header: true,
                            child: Text(
                              'Never miss a payment date',
                              style: t.h2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Gap.s8,
                          Text(
                            'We will only tell you what matters to your plan.',
                            style: t.lead,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.s22),
                          AppCard(
                            padding: const EdgeInsets.all(Space.s18),
                            child: Column(
                              children: [
                                for (var i = 0; i < reasons.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < reasons.length - 1
                                          ? Space.s12
                                          : 0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: Space.s2,
                                          ),
                                          child: Icon(
                                            reasons[i].$1,
                                            size: 20,
                                            color: reasons[i].$2,
                                          ),
                                        ),
                                        const SizedBox(width: Space.s12),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              style: t.base,
                                              children: reasons[i].$3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s22),
                          Text(
                            'Your inbox in the app shows everything either '
                            'way. Change this any time in Account.',
                            style: t.tiny.copyWith(height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.white,
              border: Border(top: BorderSide(color: c.line)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              Space.s12,
              Space.s16,
              Space.s16,
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppButton.primary(
                    'Turn on notifications',
                    large: true,
                    block: true,
                    busy: _busy,
                    onPressed: () => unawaited(_allow()),
                  ),
                ),
              ),
            ),
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
