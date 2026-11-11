import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/product_card.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/home/data/dashboard_models.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Brand on the left; notifications (with an unread dot) and the account
/// avatar on the right. White with a hairline under it, behind the status
/// bar too (canvas `.topw`).
class HomeHeader extends StatelessWidget {
  const new({required this.unread, required this.initials, super.key});

  final int unread;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.white,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.s10,
            Space.s12,
          ),
          // The brand lockup and the initials are logos: they don't grow with
          // the text size (the buttons keep their labels for screen readers).
          child: Row(
            children: [
              Flexible(
                child: MediaQuery.withNoTextScaling(
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(child: BrandHeader()),
                  ),
                ),
              ),
              const SizedBox(width: Space.s4),
              Stack(
                children: [
                  AppIconButton(
                    icon: Icons.notifications_none_rounded,
                    size: 22,
                    label: unread == 0
                        ? 'Notifications'
                        : 'Notifications, $unread unread',
                    onPressed: () => context.pushOnce(Routes.notifications),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 9,
                      right: 10,
                      child: IgnorePointer(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: c.apayCoral,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Space.s4),
              Pressable(
                onTap: () => context.go(Routes.account),
                semanticLabel: 'Account',
                excludeChildSemantics: true,
                child: Center(
                  child: MediaQuery.withNoTextScaling(
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials,
                        style: t.base.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
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

/// "AK" from "Ayesha Khan".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// No limit and never applied: the call to apply (canvas "Home · no
/// limit yet").
class ApplyHero extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.s20),
      decoration: BoxDecoration(
        gradient: c.apayGradient,
        borderRadius: BorderRadius.circular(Radii.list),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid ink on the gradient (brief §4), not the canvas's muted.
          Text(
            'NO LIMIT YET',
            style: t.tiny.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Gap.s10,
          Text('Get your AtomPay limit', style: t.h1b.copyWith(height: 1.15)),
          Gap.s10,
          Text(
            'About five minutes. Your limit is set from your income, once we '
            'have verified your identity and address.',
            style: t.base.copyWith(color: c.ink),
          ),
          Gap.s14,
          AppButton.dark(
            'Apply for your limit',
            onPressed: () => context.pushOnce(Routes.applicationStep(1)),
          ),
        ],
      ),
    );
  }
}

/// The server's banner while there's no limit: under review, rejected,
/// or a step still to do.
class StatusBanner extends StatelessWidget {
  const new({required this.banner, super.key});

  final HomeBanner banner;

  /// `apply`/`profile` start the wizard; `application` opens the income
  /// step.
  static String? routeFor(String? action) => switch (action) {
    'apply' || 'profile' => Routes.applicationStep(1),
    'application' => Routes.applicationStep(3),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final tone = switch (banner.tone) {
      'done' => NoteTone.green,
      'blocked' => NoteTone.rose,
      _ => NoteTone.amber,
    };
    final route = routeFor(banner.action);
    final t = context.text;
    return Note(
      tone: tone,
      spans: [
        TextSpan(
          text: banner.title,
          style: t.base.copyWith(fontWeight: FontWeight.w800),
        ),
        if (banner.text != null) TextSpan(text: '\n${banner.text}'),
      ],
      action: banner.cta == null || route == null
          ? null
          : TextLink(banner.cta!, onPressed: () => context.pushOnce(route)),
    );
  }
}

/// "Where you are": the six stages from the server.
class StagesCard extends StatelessWidget {
  const new({required this.stages, super.key});

  final List<Stage> stages;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return AppCard(
      padding: const EdgeInsets.all(Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Where you are', style: t.h4),
                ),
              ),
              const SizedBox(width: Space.s12),
              Text('Six stages', style: t.tiny),
            ],
          ),
          Gap.s14,
          StagesTrack(stages: stages),
        ],
      ),
    );
  }
}

/// The six stages from the server as a stepper.
class StagesTrack extends StatelessWidget {
  const new({required this.stages, super.key});

  final List<Stage> stages;

  @override
  Widget build(BuildContext context) => Track([
    for (final s in stages)
      TrackStep(
        title: s.title,
        hint: s.hint,
        state: switch (s.state) {
          'done' => TrackState.done,
          'current' => TrackState.now,
          'blocked' => TrackState.stop,
          _ => TrackState.upcoming,
        },
      ),
  ]);
}

/// The earliest unpaid instalment, with its plan's three-month bar.
class NextPaymentCard extends StatelessWidget {
  const new({required this.due, this.plan, this.withButton = false, super.key});

  final Instalment due;

  /// The order it belongs to, for "2nd of 3" and the bar. Null while
  /// `/plans` loads.
  final Plan? plan;

  /// Tablet: a "See the plan" button instead of tapping the card.
  final bool withButton;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final p = plan?.progress;
    final ofThree = p != null && p.totalCount == 3;
    final which = p == null || p.totalCount == 0
        ? null
        : '${ordinal(p.paidCount + 1)} of ${p.totalCount}';
    final badge = switch (due.state) {
      'late' => const AppBadge.rose('Late'),
      'due' => AppBadge.amber('Due ${dayMonth(due.dueDate)}'),
      _ => AppBadge.grey('Due ${dayMonth(due.dueDate)}'),
    };
    void open() => context.pushOnce(Routes.plan(due.orderId));
    // Canvas: "2nd of 3 · OXY 3218L Android" left, the reference right.
    final what = [?which, ?due.productTitle].join(' · ');
    final reference = due.orderReference;
    final details = [if (what.isNotEmpty) what, ?reference].join(' · ');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Next payment'),
                  Gap.s6,
                  Semantics(
                    label: rsSpoken(due.amount),
                    excludeSemantics: true,
                    child: Text(
                      rs(due.amount),
                      style: t.h1.copyWith(height: 1.05),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s12),
            badge,
          ],
        ),
        if (ofThree) ...[
          Gap.s12,
          Mini3([
            for (var i = 0; i < 3; i++)
              if (i < p.paidCount)
                MonthState.paid
              else if (i == p.paidCount)
                MonthState.next
              else
                MonthState.upcoming,
          ]),
        ],
        if (details.isNotEmpty) ...[
          Gap.s12,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(what, style: t.small)),
              if (reference != null) ...[
                const SizedBox(width: Space.s12),
                Text(reference, style: t.small),
              ],
            ],
          ),
        ],
        if (withButton) ...[
          Gap.s14,
          AppButton.ghost('See the plan', block: true, onPressed: open),
        ],
      ],
    );
    final when = due.state == 'late' ? 'late' : 'due ${dayMonth(due.dueDate)}';
    return AppCard(
      borderColor: due.state == 'late' ? c.roseLine : null,
      onTap: withButton ? null : open,
      semanticLabel: withButton
          ? null
          : 'Next payment ${rsSpoken(due.amount)}, $when'
                '${details.isEmpty ? '' : ', $details'}. Opens the plan.',
      child: body,
    );
  }
}

/// "1st", "2nd", "3rd", "4th"…
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// "Within your limit": products that fit, or why none do.
class WithinLimitSection extends StatelessWidget {
  const new({
    required this.products,
    required this.available,
    this.columns = 2,
    this.max = 2,
    this.linkLabel = 'See all',
    super.key,
  });

  final AsyncValue<List<Product>> products;
  final int available;
  final int columns;
  final int max;
  final String linkLabel;

  @override
  Widget build(BuildContext context) {
    final list = products.value;
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The link's 48 dp target already adds the canvas's extra space
        // around the heading.
        SectionHeader(
          'Within your limit',
          action: linkLabel,
          onAction: () => context.go(Routes.shop),
        ),
        Gap.s8,
        if (list == null && products.hasError)
          AppCard(
            child: Text(
              "We couldn't load products. Pull down to try again.",
              style: t.small,
            ),
          )
        else if (list == null)
          LoadingShape(
            label: 'Loading products',
            child: _Grid(
              columns: columns,
              children: [
                for (var i = 0; i < columns; i++) const ProductCardSkeleton(),
              ],
            ),
          )
        else if (list.isEmpty)
          // The canvas starts with "The lowest-priced eligible product is
          // Rs. …": that needs a figure from the API (brief §2).
          AppCard(
            padding: const EdgeInsets.all(Space.s22),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.greySoft,
                    borderRadius: BorderRadius.circular(Radii.note),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 22,
                    color: c.body,
                  ),
                ),
                Gap.s8,
                Text(
                  'Nothing fits ${rs(available)} right now',
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                Gap.s8,
                Text(
                  'Your limit has to cover the whole price, because nothing '
                  'is paid up front.',
                  style: t.small,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          _Grid(
            columns: columns,
            children: [
              for (final p in list.take(max))
                ProductCard(
                  title: p.title,
                  brand: p.brand,
                  price: p.price,
                  monthly: p.monthly,
                  imageUrl: p.imageUrl,
                  onTap: () => context.pushOnce(Routes.product(p.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Equal-width columns with rows that size to their content.
class _Grid extends StatelessWidget {
  const new({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(Gap.s12);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: Space.s12),
                Expanded(
                  child: i + j < children.length
                      ? children[i + j]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// "How to buy with AtomPay" and the way out to Atomshop.pk.
class HowToBuyCard extends StatelessWidget {
  const new({required this.onShop, super.key});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final bold = TextStyle(color: c.ink, fontWeight: FontWeight.w700);
    Widget step(int n, List<InlineSpan> text, {bool last = false}) => Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Space.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: t.small.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Text.rich(TextSpan(style: t.base, children: text)),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('How to buy with AtomPay', style: t.h4),
          ),
          Gap.s14,
          step(1, [
            const TextSpan(text: 'Find a product with the '),
            TextSpan(text: 'AtomPay eligible', style: bold),
            const TextSpan(text: ' badge on Atomshop.pk.'),
          ]),
          step(2, [
            const TextSpan(text: 'Choose '),
            TextSpan(text: 'AtomPay', style: bold),
            const TextSpan(text: ' at checkout. Nothing is paid up front.'),
          ]),
          step(3, last: true, [
            const TextSpan(text: 'Pay the cash price in '),
            TextSpan(text: 'three equal months', style: bold),
            const TextSpan(text: ', the last one taking the rounding.'),
          ]),
          Gap.s16,
          AppButton.dark(
            'Shop on Atomshop.pk',
            block: true,
            trailingIcon: Icons.north_east,
            semanticLabel: 'Shop on Atomshop.pk, opens outside the app',
            onPressed: onShop,
          ),
        ],
      ),
    );
  }
}

/// A card that opens Ask Atom with a suggested question (canvas: apay
/// wash, rose chevron).
class AskAtomCard extends StatelessWidget {
  const new({required this.question, super.key});

  final String question;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return AppCard(
      color: c.apayWash,
      borderColor: c.apayLine,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s14,
      ),
      onTap: () => context.pushOnce(Routes.atom),
      semanticLabel: 'Ask Atom: "$question"',
      child: Row(
        children: [
          const AtomAvatar(),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Atom',
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('"$question"', style: t.small.copyWith(color: c.body)),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          Icon(Icons.chevron_right, size: 20, color: c.rose),
        ],
      ),
    );
  }
}

/// Home's loading skeleton, in the shape of the repaying home (canvas
/// HomeRepaying, loading).
class HomeSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line(double widthFactor, double height, {double? radius}) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Skeleton(height: height, radius: radius ?? Radii.pill),
        );
    return LoadingShape(
      label: 'Loading your home',
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line(0.46, 26, radius: 10),
            Gap.s14,
            const Skeleton(height: 160, radius: Radii.card),
            Gap.s14,
            Container(
              padding: const EdgeInsets.all(Space.s18),
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line(0.34, 10),
                  Gap.s12,
                  line(0.52, 24, radius: Space.s8),
                  Gap.s12,
                  line(0.7, 12),
                  Gap.s12,
                  line(1, 8),
                ],
              ),
            ),
            Gap.s14,
            Row(
              children: [
                Expanded(child: line(0.8, 18, radius: Space.s8)),
                const Spacer(),
                const Skeleton(width: 64),
              ],
            ),
            Gap.s14,
            const _Grid(
              columns: 2,
              children: [ProductCardSkeleton(), ProductCardSkeleton()],
            ),
          ],
        ),
      ),
    );
  }
}
