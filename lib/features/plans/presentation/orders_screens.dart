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
import 'package:atompay_mobile/core/widgets/pressable.dart';
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

/// The product's picture slot: a rounded surface square with a glyph
/// (canvas `.thumb`).
class _Thumb extends StatelessWidget {
  const new({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Icon(
          Icons.desktop_windows_outlined,
          size: size * 0.47,
          color: c.glyph,
        ),
      ),
    );
  }
}

/// A skeleton block [factor] of the available width.
Widget _skelFrac(double factor, double height, {double radius = Radii.pill}) =>
    FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Skeleton(height: height, radius: radius),
    );

/// The white skeleton card (canvas `.sk-card`): padding 18, gap 12.
class _SkCard extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.s18),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Gap.s12,
            children[i],
          ],
        ],
      ),
    );
  }
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
    return TabRootBack(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        // Canvas `.topw`: a white bar, the title at the gutter, a hairline.
        appBar: const AppTopBar(title: 'My orders', leading: null),
        body: AsyncBody(
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
              icon: Icons.description_outlined,
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
              for (final p in list) ...[
                OrderCard(plan: p),
                // Canvas: 16 between full cards, 10 between compact ones.
                if (OrderBadge.of(p) == OrderBadge.repaying)
                  Gap.s16
                else
                  Gap.s10,
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s12,
                  vertical: Space.s4,
                ),
                child: Text(
                  'Every order you place with AtomPay on Atomshop.pk shows '
                  'here, whatever its status — waiting for approval, on its '
                  'way, being repaid or completed.',
                  style: context.text.tiny.copyWith(height: 1.55),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One order in the list. Repaying orders get the full card (canvas "My
/// orders"); every other status the compact one (canvas "Order states").
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
    final b = OrderBadge.of(plan);
    final title = plan.product?.title ?? 'Order ${plan.order.reference}';
    final line = summary(plan, b);
    final onTap = b.hasSchedule
        ? () => context.pushOnce(Routes.plan(plan.order.id))
        : null;
    final label =
        '$title, ${plan.order.reference}, ${b.label}. $line'
        '${b.hasSchedule ? '. Opens the schedule.' : ''}';
    if (b == OrderBadge.repaying) {
      return _FullOrderCard(
        plan: plan,
        title: title,
        badge: b,
        onTap: onTap,
        semanticLabel: label,
      );
    }
    return _CompactOrderCard(
      title: title,
      line: line,
      badge: b,
      onTap: onTap,
      semanticLabel: label,
    );
  }
}

/// Canvas "My orders" `.card.ord`: thumb, title, badge, bar, paid and due.
class _FullOrderCard extends StatelessWidget {
  const new({
    required this.plan,
    required this.title,
    required this.badge,
    required this.onTap,
    required this.semanticLabel,
  });

  final Plan plan;
  final String title;
  final OrderBadge badge;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final bar = planBar(plan.progress);
    // The delivery date isn't in the API: the order date stands in.
    final ordered = plan.order.orderedAt == null
        ? ''
        : ' · ordered ${dayMonth(plan.order.orderedAt!)}';
    return AppCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Thumb(size: 60),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('${plan.order.reference}$ordered', style: t.small),
                  ],
                ),
              ),
              const SizedBox(width: Space.s12),
              orderBadge(badge),
            ],
          ),
          if (bar != null) ...[Gap.s14, bar],
          Gap.s14,
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: t.small,
                    children: [
                      TextSpan(
                        text: rs(plan.progress.paidAmount),
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' of ${rs(plan.progress.totalAmount)} paid',
                      ),
                    ],
                  ),
                ),
              ),
              if (plan.nextDue != null) ...[
                const SizedBox(width: Space.s12),
                AppBadge.amber('Due ${dayMonth(plan.nextDue!.dueDate)}'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Canvas "Order states" `.os`: title and badge, one line under them.
class _CompactOrderCard extends StatelessWidget {
  const new({
    required this.title,
    required this.line,
    required this.badge,
    required this.onTap,
    required this.semanticLabel,
  });

  final String title;
  final String line;
  final OrderBadge badge;
  final VoidCallback? onTap;
  final String semanticLabel;

  static const _radius = BorderRadius.all(Radius.circular(Space.s18));

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s14,
      ),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: _radius,
        border: Border.all(
          color: badge == OrderBadge.late ? c.roseLine : c.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Space.s10),
              orderBadge(badge),
            ],
          ),
          Gap.s6,
          Text(line, style: t.small),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: semanticLabel, child: box);
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      borderRadius: _radius,
      pressedColor: c.primarySoft.withValues(alpha: 0.5),
      child: box,
    );
  }
}

/// Canvas "Orders · loading": three cards in the order card's shape.
class _OrdersSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => LoadingShape(
    label: 'Loading your orders',
    child: Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) Gap.s14,
            _SkCard(
              children: [
                Row(
                  children: [
                    const Skeleton(width: 52, height: 52, radius: Radii.input),
                    const SizedBox(width: Space.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skelFrac(0.7, 14),
                          Gap.s8,
                          _skelFrac(0.45, 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.s12),
                    const Skeleton(width: 70, height: 22),
                  ],
                ),
                const Skeleton(height: 8),
                Row(
                  children: [
                    Expanded(child: _skelFrac(0.5, 12)),
                    const SizedBox(width: Space.s12),
                    const Skeleton(width: 76, height: 22),
                  ],
                ),
              ],
            ),
          ],
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
        actions: [
          if (b != null)
            Padding(
              padding: const EdgeInsets.only(right: Space.s8),
              child: Center(child: orderBadge(b)),
            ),
        ],
      ),
      body: AsyncBody(
        value: plan,
        loading: const _DetailSkeleton(),
        onRetry: () => ref.invalidate(planDetailProvider(orderId)),
        notFound: "We can't find this order",
        notFoundBody:
            'It may belong to another account, or the link is out of date.',
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

/// Canvas "Order · loading": summary card, heading, three rows, a button.
class _DetailSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget stat() => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skelFrac(0.8, 16, radius: Space.s8),
          Gap.s6,
          _skelFrac(0.5, 10),
        ],
      ),
    );
    Widget row() => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s12,
      ),
      child: Row(
        children: [
          const Skeleton(width: 36, height: 36),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_skelFrac(0.5, 13), Gap.s8, _skelFrac(0.35, 10)],
            ),
          ),
          const SizedBox(width: Space.s12),
          const Skeleton(width: 70, height: 13),
        ],
      ),
    );
    return LoadingShape(
      label: 'Loading this order',
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SkCard(
              children: [
                Row(
                  children: [
                    const Skeleton(width: 56, height: 56, radius: Radii.input),
                    const SizedBox(width: Space.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skelFrac(0.65, 16),
                          Gap.s8,
                          _skelFrac(0.8, 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const Skeleton(height: 8),
                Row(
                  children: [
                    stat(),
                    const SizedBox(width: Space.s10),
                    stat(),
                    const SizedBox(width: Space.s10),
                    stat(),
                  ],
                ),
              ],
            ),
            Gap.s14,
            _skelFrac(0.3, 16, radius: Space.s8),
            Gap.s14,
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(Radii.list),
                border: Border.all(color: c.line),
              ),
              child: Column(
                children: [
                  row(),
                  Divider(height: 1, color: c.line),
                  row(),
                  Divider(height: 1, color: c.line),
                  row(),
                ],
              ),
            ),
            Gap.s14,
            const Skeleton(height: Sizes.target),
          ],
        ),
      ),
    );
  }
}

/// "10th": the day of the month as an ordinal.
String _ordinalDay(int day) {
  final teen = day % 100 >= 11 && day % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$day$suffix';
}

class _Detail extends StatelessWidget {
  const new({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final o = plan.order;
    final late = plan.instalments.where((i) => i.state == 'late').toList();
    final upcoming = plan.instalments
        .where((i) => i.state == 'due' || i.state == 'upcoming')
        .toList();

    // Canvas "Payment late": only what was missed and how to sort it out.
    if (late.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          _LateView(late: late, next: upcoming.firstOrNull, orderId: o.id),
        ],
      );
    }

    // "Due on the 10th", only when every instalment falls on the same day.
    final days = plan.instalments.map((i) => i.dueDate.day).toSet();
    final dueDay = days.length == 1 ? days.single : null;

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        _SummaryCard(plan: plan),
        if (plan.instalments.isNotEmpty) ...[
          Gap.s14,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Schedule', style: t.h4),
                ),
              ),
              if (dueDay != null)
                Text('Due on the ${_ordinalDay(dueDay)}', style: t.tiny),
            ],
          ),
          Gap.s14,
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
        Gap.s14,
        AppButton.ghost(
          'Key Fact Statement',
          block: true,
          onPressed: () => context.pushOnce(Routes.kfs(o.id)),
        ),
        Gap.s14,
        AppButton.ghost(
          'Ask Atom about a payment',
          block: true,
          onPressed: () => context.pushOnce(Routes.atom),
        ),
      ],
    );
  }
}

/// The top card: product, terms, progress, the server's figures, and where
/// the order is in its life.
class _SummaryCard extends StatelessWidget {
  const new({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final o = plan.order;
    final pr = plan.progress;
    final b = OrderBadge.of(plan);

    Widget stat(int value, String label, {Color? color}) => Expanded(
      child: Semantics(
        label: '${rsSpoken(value)} $label',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s10,
            vertical: Space.s12,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FigureText(rs(value), style: t.h4.copyWith(color: color)),
              const SizedBox(height: Space.s2),
              Text(label, style: t.tiny),
            ],
          ),
        ),
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Thumb(size: 56),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.product?.title ?? 'Order ${o.reference}',
                      style: t.h4,
                    ),
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
                  ],
                ),
              ),
            ],
          ),
          if (pr.totalCount > 0) ...[
            Gap.s14,
            _ProgressBar(
              percent: pr.percent,
              label: '${pr.paidCount} of ${pr.totalCount} months paid',
            ),
            Gap.s14,
            Row(
              children: [
                stat(pr.totalAmount, 'total'),
                const SizedBox(width: Space.s8),
                stat(pr.paidAmount, 'paid', color: c.green),
                const SizedBox(width: Space.s8),
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
          if (b == OrderBadge.repaying) ...[
            Gap.s14,
            const _Chain(
              done: ['Placed', 'Approved', 'Delivered'],
              now: 'Repaying',
            ),
          ],
        ],
      ),
    );
  }
}

/// Canvas `.pbar`: one 8 dp track, green to the server's percent.
class _ProgressBar extends StatelessWidget {
  const new({required this.percent, required this.label});

  final int percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          height: 8,
          color: c.line,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (percent.clamp(0, 100)) / 100,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.green,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Canvas `.chain`: "Placed — Approved — Delivered — Repaying".
class _Chain extends StatelessWidget {
  const new({required this.done, required this.now});

  final List<String> done;
  final String now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.tiny.copyWith(
      color: c.green,
      fontWeight: FontWeight.w700,
    );
    final dash = Container(width: 14, height: 2, color: c.green);
    return Semantics(
      label: [...done, now].join(', '),
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.s6,
        runSpacing: Space.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final step in done) ...[Text(step, style: style), dash],
          Text(now, style: style.copyWith(color: c.primary)),
        ],
      ),
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
    final c = context.colors;
    final (badge, icon, tone) = switch (i.state) {
      'paid' => (const AppBadge.green('Paid'), Icons.check, TileTone.green),
      'late' => (
        const AppBadge.rose('Late'),
        Icons.error_outline,
        TileTone.rose,
      ),
      'due' => (const AppBadge.amber('Due'), Icons.schedule, TileTone.amber),
      _ => (
        const AppBadge.grey('Upcoming'),
        Icons.calendar_today_outlined,
        TileTone.grey,
      ),
    };
    // The payment method isn't in the API, so "paid 9 Nov" stands alone.
    final when = [
      'Due ${dayMonthYear(i.dueDate)}',
      if (i.paidOn != null) 'paid ${dayMonth(i.paidOn!)}',
      if (rounding) 'takes the rounding',
    ].join(' · ');
    final row = ListRow(
      title: i.label,
      icon: icon,
      tileTone: tone,
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
    // Canvas: the month that is due sits on an amber wash.
    if (i.state != 'due') return row;
    return ColoredBox(color: c.amberWash, child: row);
  }
}

/// "Payment late": what was missed and how to sort it out. No coercive
/// recovery language (brief §11): the action is "Talk to us".
class _LateView extends StatelessWidget {
  const new({required this.late, required this.orderId, this.next});

  final List<Instalment> late;
  final Instalment? next;
  final int orderId;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in late) ...[_LateCard(i: i, next: next), Gap.s14],
        AppCard(
          padding: const EdgeInsets.all(Space.s18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Ways to pay', style: t.h4)),
              Gap.s12,
              Text(
                'By hand, bank transfer, JazzCash, EasyPaisa or online. It '
                'shows here once Atomshop records it.',
                style: t.small.copyWith(color: c.body),
              ),
            ],
          ),
        ),
        Gap.s14,
        const Note(
          tone: NoteTone.blue,
          icon: Icons.chat_bubble_outline,
          text:
              'Having trouble paying this month? Talk to us before the next '
              'date — it is easier to sort out early.',
        ),
        Gap.s14,
        AppButton.primary(
          'Talk to us',
          block: true,
          onPressed: () => context.pushOnce(Routes.help),
        ),
        Gap.s14,
        AppButton.ghost(
          'See the Key Fact Statement',
          block: true,
          onPressed: () => context.pushOnce(Routes.kfs(orderId)),
        ),
      ],
    );
  }
}

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
    return AppCard(
      padding: const EdgeInsets.all(Space.s18),
      borderColor: c.roseLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow(i.label, atomPay: true),
          Gap.s6,
          Semantics(
            label: rsSpoken(i.amount),
            excludeSemantics: true,
            child: Text(rs(i.amount), style: t.h1.copyWith(height: 1.2)),
          ),
          Gap.s4,
          Text(
            'Was due on ${dayMonthYear(i.dueDate)}'
            '${_ago(days)}',
            style: t.small,
          ),
          Gap.s14,
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
    );
  }
}

/// " · 6 days ago", or nothing on the day itself.
String _ago(int days) => switch (days) {
  <= 0 => '',
  1 => ' · 1 day ago',
  _ => ' · $days days ago',
};
