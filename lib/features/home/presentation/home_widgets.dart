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
/// avatar on the right.
class HomeHeader extends StatelessWidget {
  const new({required this.unread, required this.initials, super.key});

  final int unread;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s8,
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
          const SizedBox(width: Space.s8),
          Stack(
            children: [
              AppIconButton(
                icon: Icons.notifications_none_rounded,
                label: unread == 0
                    ? 'Notifications'
                    : 'Notifications, $unread unread',
                onPressed: () => context.pushOnce(Routes.notifications),
              ),
              if (unread > 0)
                Positioned(
                  top: 12,
                  right: 12,
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
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: c.primarySoft,
                  child: Text(
                    initials,
                    style: context.text.small.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(Space.s20),
      decoration: BoxDecoration(
        gradient: c.apayGradient,
        borderRadius: BorderRadius.circular(Radii.list),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NO LIMIT YET',
            style: t.tiny.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Gap.s8,
          Text('Get your AtomPay limit', style: t.h2),
          Gap.s8,
          Text(
            'About five minutes. Your limit is set from your income, once we '
            'have verified your identity and address.',
            style: t.base.copyWith(color: c.ink),
          ),
          Gap.s16,
          AppButton.dark(
            'Apply for your limit',
            block: true,
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
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where you are', style: context.text.h4),
        Text('Six stages', style: context.text.small),
        Gap.s16,
        StagesTrack(stages: stages),
      ],
    ),
  );
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
    final details = [
      ?which,
      ?due.productTitle,
      ?due.orderReference,
    ].join(' · ');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Next payment', style: t.small)),
            badge,
          ],
        ),
        Gap.s4,
        Semantics(
          label: rsSpoken(due.amount),
          excludeSemantics: true,
          child: Text(rs(due.amount), style: t.h1b),
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
        Gap.s8,
        Text(details, style: t.small),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              style: context.text.small,
            ),
          )
        else if (list == null)
          const LoadingShape(
            label: 'Loading products',
            child: SkeletonCard(height: 220),
          )
        else if (list.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing fits ${rs(available)} right now',
                  style: context.text.h4,
                ),
                Gap.s4,
                Text(
                  'Your limit has to cover the whole price, because nothing '
                  'is paid up front.',
                  style: context.text.small,
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
    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: c.primarySoft,
            child: Text(
              '$n',
              style: t.small.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: Space.s12),
          Expanded(child: Text(text, style: t.base)),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How to buy with AtomPay', style: t.h4),
          Gap.s14,
          step(
            1,
            'Find a product with the AtomPay eligible badge on Atomshop.pk.',
          ),
          step(2, 'Choose AtomPay at checkout. Nothing is paid up front.'),
          step(
            3,
            'Pay the cash price in three equal months, the last one taking '
            'the rounding.',
          ),
          Gap.s4,
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

/// A card that opens Ask Atom with a suggested question.
class AskAtomCard extends StatelessWidget {
  const new({required this.question, super.key});

  final String question;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return AppCard(
      onTap: () => context.pushOnce(Routes.atom),
      semanticLabel: 'Ask Atom: "$question"',
      child: Row(
        children: [
          const AtomAvatar(size: 40),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Atom',
                  style: t.label.copyWith(fontWeight: FontWeight.w800),
                ),
                Text('"$question"', style: t.small),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.glyph),
        ],
      ),
    );
  }
}

/// Home's loading skeleton, in its own shape.
class HomeSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const LoadingShape(
    label: 'Loading your home',
    child: Padding(
      padding: EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 140, height: 22),
          Gap.s16,
          SkeletonCard(height: 150),
          Gap.s14,
          SkeletonCard(),
          Gap.s14,
          SkeletonCard(height: 220),
        ],
      ),
    ),
  );
}
