import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/core/widgets/value_row.dart';
import 'package:atompay_mobile/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/domain/plans_controller.dart';
import 'package:atompay_mobile/features/plans/presentation/plan_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product, order totals, progress and the full schedule (handbook §5.9).
class PlanDetailScreen extends ConsumerWidget {
  const new({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(planProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.value?.order.reference ?? l10n.orderTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(planProvider(orderId).future),
        child: switch (plan) {
          AsyncValue(:final value?) => _Body(value),
          AsyncError(:final error) => ListView(
            children: [
              MessageView(
                message: switch (error) {
                  NotFound() => l10n.planNotFound,
                  final ApiException e => apiErrorText(l10n, e),
                  _ => l10n.genericError,
                },
                actionLabel: error is NotFound ? null : l10n.tryAgain,
                onAction: () => ref.invalidate(planProvider(orderId)),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const new(this.plan);

  final Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final order = plan.order;
    final progress = plan.progress;
    final product = plan.product;
    final support = ref.watch(appConfigProvider).support;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.x24, bottom: Space.x4),
      child: Text(title.toUpperCase(), style: text.eyebrow),
    );

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        PlanImage(product: product),
        const SizedBox(height: Space.x16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                product?.title ?? l10n.productRemoved,
                style: text.headline,
              ),
            ),
            const SizedBox(width: Space.x8),
            StatusPill(
              label: planStateLabel(l10n, plan.state),
              tone: planStateTone(plan.state),
            ),
          ],
        ),
        const SizedBox(height: Space.x4),
        Text(
          [
            order.statusLabel,
            if (order.orderedAt case final at?) l10n.orderedOn(Dates.short(at)),
          ].join(' · '),
          style: text.bodySmall,
        ),
        if (product?.shopUrl case final url? when url.isNotEmpty) ...[
          const SizedBox(height: Space.x12),
          GhostButton(
            label: l10n.viewOnAtomShop,
            onPressed: () => openLink(context, Uri.parse(url)),
          ),
        ],
        section(l10n.orderTitle),
        ValueRow(label: l10n.totalPriceLabel, value: pkr(order.totalPrice)),
        ValueRow(label: l10n.downPaymentLabel, value: pkr(order.advance)),
        ValueRow(label: l10n.financedLabel, value: pkr(order.financed)),
        if (order.tenure case final months?)
          ValueRow(label: l10n.tenureLabel, value: l10n.monthsCount(months)),
        const SizedBox(height: Space.x16),
        SpectrumBar(percent: progress.percent),
        const SizedBox(height: Space.x8),
        Text(
          l10n.instalmentsPaid(progress.paidCount, progress.totalCount),
          style: text.body,
        ),
        Text(
          l10n.paidOfTotal(pkr(progress.paidAmount), pkr(progress.totalAmount)),
          style: text.figure(text.bodySmall),
        ),
        ValueRow(
          label: l10n.remainingLabel,
          value: pkr(progress.remainingAmount),
        ),
        if (plan.instalments.isNotEmpty) ...[
          section(l10n.scheduleTitle),
          for (final (i, instalment) in plan.instalments.indexed) ...[
            if (i > 0) const Divider(),
            InstalmentRow(instalment: instalment),
          ],
        ],
        const SizedBox(height: Space.x24),
        AppBanner(tone: StatusTone.info, title: l10n.payOffline),
        if (support.phone != null ||
            support.whatsapp != null ||
            support.email != null) ...[
          const SizedBox(height: Space.x8),
          if (support.phone case final phone?)
            TextButton.icon(
              onPressed: () =>
                  openLink(context, Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call_outlined),
              label: Text('${l10n.supportPhone} · $phone'),
            ),
          if (support.whatsapp case final wa?)
            TextButton.icon(
              onPressed: () => openLink(
                context,
                Uri.https('wa.me', '/${wa.replaceAll(RegExp(r'\D'), '')}'),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: Text('${l10n.supportWhatsapp} · $wa'),
            ),
          if (support.email case final email?)
            TextButton.icon(
              onPressed: () =>
                  openLink(context, Uri(scheme: 'mailto', path: email)),
              icon: const Icon(Icons.mail_outline),
              label: Text('${l10n.supportEmail} · $email'),
            ),
        ],
      ],
    );
  }
}
