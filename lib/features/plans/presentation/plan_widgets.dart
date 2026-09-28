import 'package:atompay_mobile/core/models/instalment.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

String planStateLabel(AppLocalizations l10n, String state) => switch (state) {
  'late' => l10n.planLate,
  'completed' => l10n.planCompleted,
  _ => l10n.planOnTrack,
};

StatusTone planStateTone(String state) => switch (state) {
  'late' => StatusTone.blocked,
  'completed' => StatusTone.ok,
  _ => StatusTone.neutral,
};

/// The product picture (public AtomShop URL), or a logo placeholder when the
/// product was removed or the image fails.
class PlanImage extends StatelessWidget {
  const new({required this.product, super.key});

  final PlanProduct? product;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final placeholder = ColoredBox(
      color: t.line2,
      child: const Center(child: AtomLogo(size: 40)),
    );
    final url = product?.pictureUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.input),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: url == null || url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                semanticLabel: product?.title,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}

/// A plan in the list (handbook §4.6).
class PlanCard extends StatelessWidget {
  const new({required this.plan, required this.onTap, super.key});

  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final p = plan.progress;
    final next = plan.nextDue;
    final due = next == null ? null : Dates.parseDate(next.dueDate);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanImage(product: plan.product),
              const SizedBox(height: Space.x12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.product?.title ?? l10n.productRemoved,
                      style: text.title,
                    ),
                  ),
                  if (plan.state != 'on_track') ...[
                    const SizedBox(width: Space.x8),
                    StatusPill(
                      label: planStateLabel(l10n, plan.state),
                      tone: planStateTone(plan.state),
                    ),
                  ],
                ],
              ),
              Text(plan.order.reference, style: text.bodySmall),
              const SizedBox(height: Space.x12),
              SpectrumBar(percent: p.percent),
              const SizedBox(height: Space.x8),
              Text(
                l10n.paidOfTotal(pkr(p.paidAmount), pkr(p.totalAmount)),
                style: text.figure(text.body),
              ),
              if (next != null && due != null)
                Text(
                  l10n.nextDueLine(pkr(next.amount), Dates.short(due)),
                  style: text.figure(text.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One scheduled payment: label, due date, amount and state (§4.6).
class InstalmentRow extends StatelessWidget {
  const new({required this.instalment, super.key});

  final Instalment instalment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final i = instalment;
    final due = Dates.parseDate(i.dueDate);
    final paidOn = Dates.parseDate(i.paidOn);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.label, style: text.label),
                  Text(
                    paidOn != null
                        ? l10n.paidOn(Dates.short(paidOn))
                        : (due == null ? i.dueDate : Dates.short(due)),
                    style: text.figure(text.bodySmall),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.x12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pkr(i.paidAmount ?? i.amount),
                  style: text.figure(text.label),
                ),
                const SizedBox(height: Space.x4),
                StatusPill(
                  label: instalmentStateLabel(l10n, i.state),
                  tone: StatusTone.fromApi(i.state),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
