import 'dart:async';

import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/dashboard/data/dashboard_models.dart';
import 'package:atompay_mobile/features/dashboard/domain/dashboard_controller.dart';
import 'package:atompay_mobile/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home: the dashboard (handbook §5.6). Refreshes on pull, on resume and
/// after any form submit (the submit controllers invalidate it).
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(dashboardProvider.future).then<void>((_) {}, onError: (_) {}),
      ref.read(authControllerProvider.notifier).refreshUser(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final dashboard = ref.watch(dashboardProvider);
    final name = auth is SignedIn ? auth.user.shortName : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.greeting(name)),
        actions: [
          _Bell(count: dashboard.value?.unreadNotifications ?? 0),
          const SizedBox(width: Space.x8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: switch (dashboard) {
          // Keep showing the last data while a refresh is in flight.
          AsyncValue(:final value?) => _Dashboard(value),
          AsyncError(:final error) => ListView(
            children: [
              const SizedBox(height: Space.x40),
              MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(dashboardProvider),
              ),
            ],
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const new(this.d);

  final Dashboard d;

  /// `banner.action` → where its button goes (handbook §5.6).
  void _onBannerAction(BuildContext context, String? action) {
    switch (action) {
      case 'apply':
        // Profile first, then straight on to income once it's saved.
        unawaited(context.push(Routes.profileEditThenApply));
      case 'profile':
        unawaited(context.push(Routes.profileEdit));
      case 'application':
        unawaited(context.push(Routes.application));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final shopUrl = ref.watch(appConfigProvider).shopUrl;
    final banner = d.banner;
    final plans = d.plans;

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        AppBanner(
          tone: StatusTone.fromApi(banner.tone),
          title: banner.title,
          text: banner.text,
          cta: banner.cta,
          onCta: banner.action == null
              ? null
              : () => _onBannerAction(context, banner.action),
        ),
        const SizedBox(height: Space.x16),
        LimitCard(limit: d.limit),
        if (d.nextDue case final due?) ...[
          const SizedBox(height: Space.x16),
          NextDueCard(
            instalment: due,
            onTap: () => unawaited(context.push(Routes.plan(due.orderId))),
          ),
        ],
        if (plans.activeCount > 0 || plans.hasLate) ...[
          const SizedBox(height: Space.x16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(Routes.plans),
              child: Padding(
                padding: const EdgeInsets.all(Space.x20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.plansActive(plans.activeCount),
                      style: text.title,
                    ),
                    if (plans.hasLate) ...[
                      const SizedBox(height: Space.x8),
                      StatusPill(
                        label: l10n.plansLate,
                        tone: StatusTone.blocked,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        if (d.applicationStatus case final status?) ...[
          const SizedBox(height: Space.x16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.x20,
                vertical: Space.x4,
              ),
              title: Text(l10n.applicationTitle, style: text.label),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: Space.x8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(
                    label: applicationStatusLabel(l10n, status),
                    tone: StatusTone.fromApi(status),
                  ),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.applicationStatus),
            ),
          ),
        ],
        if (d.stages.isNotEmpty) ...[
          const SizedBox(height: Space.x16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.x20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.progressTitle, style: text.title),
                  const SizedBox(height: Space.x16),
                  ProcessStepper(stages: d.stages),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.x24),
        GhostButton(
          label: l10n.shopOnAtomShop,
          onPressed: () => openLink(context, Uri.parse(shopUrl)),
        ),
        const SizedBox(height: Space.x8),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: const [
        Skeleton(height: 96, radius: Radii.card),
        SizedBox(height: Space.x16),
        Skeleton(height: 220, radius: Radii.darkCard),
        SizedBox(height: Space.x16),
        Skeleton(height: 120, radius: Radii.card),
      ],
    );
  }
}

/// Notifications bell with the unread count (handbook §5.6).
class _Bell extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: count > 0
          ? l10n.unreadNotifications(count)
          : l10n.notificationsTitle,
      onPressed: () => unawaited(context.push(Routes.notifications)),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.coral,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
