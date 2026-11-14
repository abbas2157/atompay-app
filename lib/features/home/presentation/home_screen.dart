import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/home/data/dashboard_models.dart';
import 'package:atompay_mobile/features/home/presentation/home_widgets.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/notifications/presentation/notif_permission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home (brief §9): three states from `/dashboard` (no limit, approved,
/// repaying) and a two-column layout from 600 dp.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  /// Reloads Home when the customer comes back to the app: a limit
  /// decided or changed meanwhile, or an Atomshop checkout, shows up
  /// without pulling to refresh (push isn't always there to say so).
  late final AppLifecycleListener _lifecycle;
  DateTime _loadedAt = DateTime.now();

  /// A quick hop to another app and back doesn't reload.
  static const _resumeGap = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (DateTime.now().difference(_loadedAt) >= _resumeGap) {
          unawaited(_refresh());
        }
      },
    );
    // After sign-in, never at launch's first frame (brief §10).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(maybeAskForNotifications(context, ref));
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _loadedAt = DateTime.now();
    ref
      ..invalidate(plansProvider)
      ..invalidate(productsWithinLimitProvider)
      ..invalidate(dashboardProvider);
    try {
      await ref.read(dashboardProvider.future);
    } on Object {
      // The toast from listenForRefreshErrors says so; old data stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForRefreshErrors(ref, dashboardProvider);
    final value = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final unread = value.value?.data.unreadNotifications ?? 0;
    return Scaffold(
      backgroundColor: context.colors.surface,
      // The white header runs behind the status bar and takes the top
      // inset itself.
      body: Column(
        children: [
          HomeHeader(unread: unread, initials: initialsOf(user?.name ?? '')),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SafeArea(
                top: false,
                bottom: false,
                child: AsyncBody(
                  value: value,
                  loading: const HomeSkeleton(),
                  onRetry: () => ref.invalidate(dashboardProvider),
                  offlineBody:
                      "Connect to Wi-Fi or mobile data and we'll load your "
                      'limit and payments.',
                  data: (cached) => ScrollToTopOnReselect(
                    controller: _scroll,
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: _HomeBody(
                        cached: cached,
                        firstName: _first(user?.name),
                        scroll: _scroll,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _first(String? name) =>
      name?.trim().split(RegExp(r'\s+')).firstOrNull;
}

class _HomeBody extends ConsumerWidget {
  const new({
    required this.cached,
    required this.firstName,
    required this.scroll,
  });

  final Cached<Dashboard> cached;
  final String? firstName;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = cached.data;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final plans = ref.watch(plansProvider).value?.data;
    final plan = d.nextDue == null
        ? null
        : plans?.where((p) => p.order.id == d.nextDue!.orderId).firstOrNull;
    final shopUrl = ref.watch(appConfigProvider).shopUrl;

    final greeting = Text(
      firstName == null || firstName!.isEmpty ? 'Hi' : 'Hi $firstName',
      style: context.text.h2,
    );
    final banner = OfflineBanner(
      what: 'your limit',
      since: cached.savedAt,
      fromCache: cached.fromCache,
    );

    final List<Widget> left;
    final List<Widget> right;
    if (!d.limit.hasLimit) {
      left = [
        if (d.applicationStatus == null)
          const ApplyHero()
        else if (d.banner != null)
          StatusBanner(banner: d.banner!),
      ];
      right = [StagesCard(stages: d.stages)];
    } else {
      final products = ref.watch(productsWithinLimitProvider);
      final limit = LimitCard(
        available: d.limit.available,
        approved: d.limit.approved,
        used: d.limit.used,
        usedPercent: d.limit.usedPercent,
        monthlyCap: d.limit.maxInstalment == 0 ? null : d.limit.maxInstalment,
      );
      if (d.nextDue == null) {
        left = [
          if (d.applicationStatus == 'pending' && d.banner != null)
            StatusBanner(banner: d.banner!)
          else
            const Note(
              tone: NoteTone.green,
              icon: Icons.check,
              text:
                  'Your limit is approved. Shop on Atomshop.pk and choose '
                  'AtomPay at checkout.',
            ),
          limit,
          if (!wide) ...[
            WithinLimitSection(
              products: products,
              available: d.limit.available,
              lowestPrice: d.lowestEligiblePrice,
            ),
          ],
          HowToBuyCard(onShop: () => Links.open(shopUrl)),
          const AskAtomCard(question: 'Which products can I buy?'),
        ];
      } else {
        left = [
          limit,
          NextPaymentCard(due: d.nextDue!, plan: plan, withButton: wide),
          if (!wide) ...[
            // The "after" figure comes from the server, never computed here.
            Note(
              tone: NoteTone.blue,
              spans: [
                const TextSpan(text: 'Your limit frees up as you pay.'),
                if (d.limit.availableAfterNext case final after?) ...[
                  TextSpan(
                    text:
                        ' After ${dayMonth(d.nextDue!.dueDate)} you will have ',
                  ),
                  TextSpan(
                    text: rs(after),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' to spend.'),
                ],
              ],
            ),
            WithinLimitSection(
              products: products,
              available: d.limit.available,
              lowestPrice: d.lowestEligiblePrice,
              linkLabel: 'All products',
            ),
          ],
          AskAtomCard(
            question: wide
                ? 'When is my next payment?'
                : 'When are my payments due?',
          ),
        ];
      }
      right = [
        if (wide) ...[
          WithinLimitSection(
            products: products,
            available: d.limit.available,
            lowestPrice: d.lowestEligiblePrice,
            columns: MediaQuery.sizeOf(context).width >= 840 ? 3 : 2,
            max: 6,
          ),
          if (d.limit.maxInstalment > 0)
            Note(
              tone: NoteTone.blue,
              text:
                  'Each monthly amount fits inside your '
                  '${rs(d.limit.maxInstalment)} monthly cap.',
            ),
        ],
      ];
    }

    List<Widget> spaced(List<Widget> items) => [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) Gap.s14, items[i]],
    ];

    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: spaced(left),
                ),
              ),
              const SizedBox(width: Space.s20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: spaced(right),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spaced([...left, ...right]),
          );

    return ListView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        banner,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.s16,
                Space.gutter,
                Space.s32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [greeting, Gap.s14, content],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
