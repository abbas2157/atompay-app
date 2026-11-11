import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/plans/application/plans_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Widget orderBadge(OrderBadge b) => switch (b) {
  OrderBadge.awaitingApproval ||
  OrderBadge.verification => AppBadge.amber(b.label),
  OrderBadge.processing ||
  OrderBadge.delivered ||
  OrderBadge.repaying => AppBadge.blue(b.label),
  OrderBadge.late => AppBadge.rose(b.label),
  OrderBadge.completed => AppBadge.green(b.label),
  OrderBadge.cancelled => AppBadge.grey(b.label),
};

/// The three-month bar for a plan, when it has three months.
Widget? planBar(PlanProgress p) {
  if (p.totalCount != 3) return null;
  return Mini3([
    for (var i = 0; i < 3; i++)
      if (i < p.paidCount)
        MonthState.paid
      else if (i == p.paidCount)
        MonthState.next
      else
        MonthState.upcoming,
  ]);
}

// ---- My orders --------------------------------------------------------------

/// Every order, whatever its status (canvas "My orders").
class OrdersScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(plansProvider);
    try {
      await ref.read(plansProvider.future);
    } on Object {
      // The toast covers it.
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForRefreshErrors(ref, plansProvider);
    final plans = ref.watch(plansProvider);
    final t = context.text;
    return TabRootBack(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.s12,
                  Space.gutter,
                  Space.s8,
                ),
                child: Semantics(
                  header: true,
                  child: Text('My orders', style: t.h2),
                ),
              ),
              Expanded(
                child: AsyncBody(
                  value: plans,
                  loading: const _OrdersSkeleton(),
                  onRetry: () => ref.invalidate(plansProvider),
                  data: (cached) => ScrollToTopOnReselect(
                    controller: _scroll,
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: _OrdersList(cached: cached, scroll: _scroll),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const new({required this.cached, required this.scroll});

  final Cached<List<Plan>> cached;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final list = cached.data;
    if (list.isEmpty) {
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: box.maxHeight,
            child: StateView(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              body:
                  'Choose AtomPay at checkout on an eligible Atomshop.pk '
                  'product and the order shows here.',
              actions: [
                AppButton.primary(
                  'See eligible products',
                  block: true,
                  onPressed: () => context.go(Routes.shop),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        OfflineBanner(
          what: 'your orders',
          since: cached.savedAt,
          fromCache: cached.fromCache,
        ),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in list) ...[OrderCard(plan: p), Gap.s12],
              Text(
                'Every order you place with AtomPay on Atomshop.pk shows '
                'here, whatever its status: waiting for approval, on its '
                'way, being repaid or completed.',
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

/// One order in the list.
class OrderCard extends StatelessWidget {
  const new({required this.plan, super.key});

  final Plan plan;

  /// The line under the title, per status.
  static String summary(Plan p, OrderBadge b) {
    final next = p.nextDue;
    final nextText = next == null
        ? ''
        : ' · next ${rs(next.amount)} on ${dayMonth(next.dueDate)}';
    return switch (b) {
      OrderBadge.awaitingApproval => 'Atomshop is reviewing this order.',
      OrderBadge.verification =>
        'We are confirming your details for this order.',
      OrderBadge.processing =>
        'Approved. Atomshop is preparing it for delivery.',
      OrderBadge.delivered =>
        'Your three months start now. The schedule appears shortly.',
      OrderBadge.repaying =>
        '${p.progress.paidCount} of ${p.progress.totalCount} paid$nextText',
      OrderBadge.late =>
        next == null
            ? 'A payment is late.'
            : '${rs(next.amount)} was due on ${dayMonth(next.dueDate)}',
      OrderBadge.completed => 'Fully repaid. Thank you.',
      OrderBadge.cancelled => 'Nothing is owed on this order.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final b = OrderBadge.of(plan);
    final title = plan.product?.title ?? 'Order ${plan.order.reference}';
    final line = summary(plan, b);
    final bar = b.hasSchedule ? planBar(plan.progress) : null;
    final ordered = plan.order.orderedAt == null
        ? ''
        : ' · ordered ${dayMonth(plan.order.orderedAt!)}';
    return AppCard(
      onTap: b.hasSchedule
          ? () => context.pushOnce(Routes.plan(plan.order.id))
          : null,
      borderColor: b == OrderBadge.late ? context.colors.roseLine : null,
      semanticLabel:
          '$title, ${plan.order.reference}, ${b.label}. $line'
          '${b.hasSchedule ? '. Opens the schedule.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('${plan.order.reference}$ordered', style: t.small),
                  ],
                ),
              ),
              const SizedBox(width: Space.s8),
              orderBadge(b),
            ],
          ),
          if (bar != null) ...[Gap.s12, bar],
          Gap.s8,
          if (b == OrderBadge.repaying)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${rs(plan.progress.paidAmount)} of '
                    '${rs(plan.progress.totalAmount)} paid',
                    style: t.small,
                  ),
                ),
                if (plan.nextDue != null)
                  AppBadge.amber('Due ${dayMonth(plan.nextDue!.dueDate)}'),
              ],
            )
          else
            Text(line, style: t.small),
        ],
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const LoadingShape(
    label: 'Loading your orders',
    child: Padding(
      padding: EdgeInsets.all(Space.gutter),
      child: Column(
        children: [
          SkeletonCard(),
          Gap.s12,
          SkeletonCard(),
          Gap.s12,
          SkeletonCard(),
        ],
      ),
    ),
  );
}

// ---- Order detail -----------------------------------------------------------

/// One order: progress, schedule, and the late state when a payment is
/// overdue (canvas "Order AS-01279", "Payment late").
class OrderDetailScreen extends ConsumerWidget {
  const new({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planDetailProvider(orderId));
    final p = plan.value;
    final b = p == null ? null : OrderBadge.of(p);
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppTopBar(
        title: p?.order.reference ?? 'Order',
        bottomBorder: true,
        actions: [
          if (b != null)
            Padding(
              padding: const EdgeInsets.only(right: Space.gutter),
              child: Center(child: orderBadge(b)),
            ),
        ],
      ),
      body: AsyncBody(
        value: plan,
        loading: const LoadingShape(
          label: 'Loading this order',
          child: Padding(
            padding: EdgeInsets.all(Space.gutter),
            child: Column(
              children: [
                SkeletonCard(lines: 4),
                Gap.s14,
                SkeletonCard(lines: 5),
              ],
            ),
          ),
        ),
        onRetry: () => ref.invalidate(planDetailProvider(orderId)),
        notFound: "We can't find this order",
        notFoundAction: AppButton.primary(
          'Go to my orders',
          block: true,
          onPressed: () => context.go(Routes.plans),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(planDetailProvider(orderId))
              ..invalidate(plansProvider);
            try {
              await ref.read(planDetailProvider(orderId).future);
            } on Object {
              // Shown by the error state.
            }
          },
          child: _Detail(plan: p),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const new({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final o = plan.order;
    final pr = plan.progress;
    final b = OrderBadge.of(plan);
    final bar = planBar(pr);
    final late = plan.instalments.where((i) => i.state == 'late').toList();
    final upcoming = plan.instalments
        .where((i) => i.state == 'due' || i.state == 'upcoming')
        .toList();

    Widget stat(int value, String label) => Expanded(
      child: Semantics(
        label: '${rsSpoken(value)} $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(rs(value), style: t.h4),
            Text(label, style: t.tiny),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        if (late.isNotEmpty) ...[
          for (final i in late) _LateCard(i: i, next: upcoming.firstOrNull),
          Gap.s14,
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(plan.product?.title ?? 'Order ${o.reference}', style: t.h4),
              Text(
                [
                  if (o.tenure != null) '${o.tenure} months',
                  if (o.advance == 0)
                    'no advance'
                  else
                    '${rs(o.advance)} advance',
                ].join(' · '),
                style: t.small,
              ),
              if (bar != null) ...[Gap.s14, bar],
              if (pr.totalCount > 0) ...[
                Gap.s14,
                Row(
                  children: [
                    stat(pr.totalAmount, 'total'),
                    stat(pr.paidAmount, 'paid'),
                    stat(pr.remainingAmount, 'to go'),
                  ],
                ),
              ] else ...[
                Gap.s12,
                KeyValueList([
                  KeyValue(
                    'Price',
                    rs(o.totalPrice),
                    spoken: rsSpoken(o.totalPrice),
                  ),
                  KeyValue('Status', o.statusLabel ?? b.label),
                ]),
              ],
            ],
          ),
        ),
        if (plan.instalments.isNotEmpty) ...[
          Gap.s16,
          const SectionHeader('Schedule'),
          Gap.s8,
          ListGroup(
            children: [
              for (var i = 0; i < plan.instalments.length; i++)
                _InstalmentRow(
                  i: plan.instalments[i],
                  rounding:
                      i == plan.instalments.length - 1 &&
                      i > 0 &&
                      plan.instalments[i].amount !=
                          plan.instalments[i - 1].amount,
                ),
            ],
          ),
        ],
        Gap.s14,
        const Note(
          tone: NoteTone.blue,
          text:
              'Pay Atomshop by hand, bank transfer, JazzCash, EasyPaisa or '
              'online. Each payment shows here once Atomshop records it.',
        ),
        Gap.s16,
        AppButton.ghost(
          'Key Fact Statement',
          block: true,
          onPressed: () => context.pushOnce(Routes.kfs(o.id)),
        ),
        Gap.s8,
        AppButton.ghost(
          'Ask Atom about a payment',
          block: true,
          onPressed: () => context.pushOnce(Routes.atom),
        ),
        Gap.s24,
        if (plan.product?.shopUrl != null)
          Text(
            o.orderedAt == null
                ? 'Placed on Atomshop.pk.'
                : 'Placed on Atomshop.pk on ${dayMonthYear(o.orderedAt!)}.',
            style: t.small.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _InstalmentRow extends StatelessWidget {
  const new({required this.i, required this.rounding});

  final Instalment i;
  final bool rounding;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final badge = switch (i.state) {
      'paid' => const AppBadge.green('Paid'),
      'late' => const AppBadge.rose('Late'),
      'due' => const AppBadge.amber('Due'),
      _ => const AppBadge.grey('Upcoming'),
    };
    final when = [
      'Due ${dayMonthYear(i.dueDate)}',
      if (i.paidOn != null) 'paid ${dayMonth(i.paidOn!)}',
      if (rounding) 'takes the rounding',
    ].join(' · ');
    return ListRow(
      title: i.label,
      summary: when,
      semanticLabel:
          '${i.label}, ${rsSpoken(i.amount)}, $when, '
          '${i.state == 'upcoming' ? 'upcoming' : i.state}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rs(i.amount),
            style: t.body.copyWith(fontWeight: FontWeight.w800),
          ),
          Gap.s4,
          badge,
        ],
      ),
    );
  }
}

/// "Payment late": what was missed and how to sort it out. No coercive
/// recovery language (brief §11): the action is "Talk to us".
class _LateCard extends StatelessWidget {
  const new({required this.i, this.next});

  final Instalment i;
  final Instalment? next;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final days = DateUtils.dateOnly(AppClock.now())
        .difference(DateUtils.dateOnly(i.dueDate))
        .inDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: c.roseSoft,
          borderColor: c.roseLine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(i.label, style: t.small.copyWith(color: c.rose)),
              Semantics(
                label: rsSpoken(i.amount),
                excludeSemantics: true,
                child: Text(rs(i.amount), style: t.h1b),
              ),
              Text(
                'Was due on ${dayMonthYear(i.dueDate)}'
                '${_ago(days)}',
                style: t.small,
              ),
              Gap.s12,
              KeyValueList([
                const KeyValue(
                  'Late charge',
                  '[CHARGES, IF ANY]',
                  placeholder: true,
                ),
                if (next != null)
                  KeyValue(
                    'Still to come',
                    '${rs(next!.amount)} · ${dayMonth(next!.dueDate)}',
                    spoken:
                        '${rsSpoken(next!.amount)} on '
                        '${dayMonth(next!.dueDate)}',
                  ),
              ]),
            ],
          ),
        ),
        Gap.s14,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ways to pay', style: t.h4),
              Gap.s6,
              Text(
                'By hand, bank transfer, JazzCash, EasyPaisa or online. It '
                'shows here once Atomshop records it.',
                style: t.base,
              ),
            ],
          ),
        ),
        Gap.s14,
        const Note(
          tone: NoteTone.blue,
          text:
              'Having trouble paying this month? Talk to us before the next '
              'date. It is easier to sort out early.',
        ),
        Gap.s12,
        AppButton.primary(
          'Talk to us',
          block: true,
          onPressed: () => context.pushOnce(Routes.help),
        ),
      ],
    );
  }
}

/// " · 6 days ago", or nothing on the day itself.
String _ago(int days) => switch (days) {
  <= 0 => '',
  1 => ' · 1 day ago',
  _ => ' · $days days ago',
};
