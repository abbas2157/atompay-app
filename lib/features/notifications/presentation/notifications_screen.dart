import 'dart:async';

import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/notifications/application/inbox_controller.dart';
import 'package:atompay_mobile/features/notifications/data/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The inbox (canvas "Notifications"). Everything pushed is here too.
class NotificationsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(inboxControllerProvider.notifier).markAllRead();
    } on Object {
      showToast("We couldn't mark them read. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(inboxControllerProvider);
    try {
      await ref.read(inboxControllerProvider.future);
    } on Object {
      // The refresh toast covers it.
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForRefreshErrors(ref, inboxControllerProvider);
    final value = ref.watch(inboxControllerProvider);
    final cached = value.value;
    final canMarkAll =
        cached != null && !cached.fromCache && cached.data.unreadCount > 0;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppTopBar(
        title: 'Notifications',
        bottomBorder: true,
        actions: [
          if (canMarkAll)
            Padding(
              padding: const EdgeInsets.only(right: Space.s8),
              child: Center(
                child: TextLink(
                  _markingAll ? 'Marking…' : 'Mark all read',
                  onPressed: _markingAll ? null : _markAll,
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: value,
        loading: const _InboxSkeleton(),
        onRetry: () => ref.invalidate(inboxControllerProvider),
        data: (cached) => RefreshIndicator(
          onRefresh: _refresh,
          child: cached.data.items.isEmpty
              ? const _Empty()
              : _InboxList(cached: cached),
        ),
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  const new({required this.cached});

  final Cached<Inbox> cached;

  /// Push and inbox share one table (brief §5.5).
  static String routeFor(NotificationPayload p) => switch (p.screen) {
    'plan' when p.orderId != null => Routes.plan(p.orderId!),
    'profile' => Routes.account,
    _ => Routes.home,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<AppNotification>>{};
    for (final n in cached.data.items) {
      groups.putIfAbsent(dayLabel(n.createdAt), () => []).add(n);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        OfflineBanner(
          what: 'your notifications',
          since: cached.savedAt,
          fromCache: cached.fromCache,
        ),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in groups.entries) ...[
                SectionLabel(entry.key),
                ListGroup(
                  children: [
                    for (final n in entry.value)
                      _Row(
                        n: n,
                        onTap: () {
                          unawaited(
                            ref
                                .read(inboxControllerProvider.notifier)
                                .markRead(n.id),
                          );
                          final to = routeFor(n.payload);
                          if (to == Routes.home || to == Routes.account) {
                            context.go(to);
                          } else {
                            unawaited(context.pushOnce(to));
                          }
                        },
                      ),
                  ],
                ),
                Gap.s16,
              ],
              Text(
                'The same alerts arrive by email. Turn email off in Account; '
                'the inbox here always works.',
                style: context.text.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Today · 10 Nov", "Yesterday · 9 Nov", "Monday · 3 Nov".
String dayLabel(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final today = DateUtils.dateOnly(now ?? AppClock.now());
  final day = DateUtils.dateOnly(local);
  final diff = today.difference(day).inDays;
  final date = DateFormat('d MMM').format(local);
  if (diff == 0) return 'Today · $date';
  if (diff == 1) return 'Yesterday · $date';
  if (diff < 7) return '${DateFormat('EEEE').format(local)} · $date';
  return DateFormat('d MMM yyyy').format(local);
}

class _Row extends StatelessWidget {
  const new({required this.n, required this.onTap});

  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Pressable(
      onTap: onTap,
      scaleOnPress: false,
      borderRadius: BorderRadius.zero,
      pressedColor: c.primarySoft,
      semanticLabel: [if (!n.read) 'Unread', n.title, ?n.body].join('. '),
      excludeChildSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.s6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n.read ? Colors.transparent : c.apayCoral,
                ),
              ),
            ),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: t.body.copyWith(
                      fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  if (n.body != null) ...[
                    const SizedBox(height: Space.s2),
                    Text(n.body!, style: t.small),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            Icon(Icons.chevron_right, color: c.glyph),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: box.maxHeight,
        child: StateView(
          icon: Icons.notifications_none_rounded,
          iconTone: StateTone.green,
          title: "You're all caught up",
          body:
              'Payment reminders and decisions on your limit will appear '
              'here.',
          actions: [
            AppButton.ghost(
              'Notification settings',
              block: true,
              onPressed: () => context.pushOnce(Routes.notificationSettings),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InboxSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const LoadingShape(
    label: 'Loading notifications',
    child: Padding(
      padding: EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 120),
          Gap.s12,
          SkeletonRow(),
          SkeletonRow(),
          SkeletonRow(),
          SkeletonRow(),
        ],
      ),
    ),
  );
}
