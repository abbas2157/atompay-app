import 'dart:async';

import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/notifications/data/notification_models.dart';
import 'package:atompay_mobile/features/notifications/domain/inbox_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Notifications inbox (handbook §5.11).
class InboxScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Near the end: fetch the next page.
      if (_scroll.position.extentAfter < 400) {
        unawaited(ref.read(inboxProvider.notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification n) async {
    unawaited(ref.read(inboxProvider.notifier).markRead(n));
    final route = routeForPayload(n.payload);
    if (route == Routes.home || route == Routes.profile) {
      context.go(route);
    } else {
      await context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inbox = ref.watch(inboxProvider);
    final unread = inbox.value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  unawaited(ref.read(inboxProvider.notifier).markAllRead()),
              child: Text(l10n.markAllRead),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(inboxProvider.future),
        child: switch (inbox) {
          AsyncValue(:final value?) when value.items.isEmpty => ListView(
            children: [MessageView(message: l10n.noNotifications)],
          ),
          AsyncValue(:final value?) => ListView.separated(
            controller: _scroll,
            itemCount: value.items.length + (value.loadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) => i >= value.items.length
                ? const Padding(
                    padding: EdgeInsets.all(Space.x16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _Tile(
                    notification: value.items[i],
                    onTap: () => unawaited(_open(value.items[i])),
                  ),
          ),
          AsyncError(:final error) => ListView(
            children: [
              MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(inboxProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final n = notification;
    final when = DateFormat('d MMM · HH:mm').format(n.createdAt.toLocal());
    return Semantics(
      button: true,
      label: n.read ? null : context.l10n.unreadLabel,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.x16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: n.read ? Colors.transparent : AppColors.violet,
                  ),
                ),
              ),
              const SizedBox(width: Space.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: text.body.copyWith(
                        fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: Space.x4),
                      Text(n.body, style: text.bodySmall),
                    ],
                    const SizedBox(height: Space.x4),
                    Text(when, style: text.figure(text.bodySmall)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
