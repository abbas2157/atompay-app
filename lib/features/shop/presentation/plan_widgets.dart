import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:flutter/material.dart';

/// The three months, advance, markup and total of a `/plan-preview`, with
/// the processing-fee disclaimer (brief §2). Nothing here is computed.
/// Canvas "Your plan": rose eyebrow, month rows, three total tiles.
class PlanBreakdown extends StatelessWidget {
  const new({required this.plan, this.title, super.key});

  final PlanPreview plan;

  /// Shown as the rose eyebrow ("Your AtomPay plan").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final months = plan.instalments;

    Widget month(int i) {
      final rounding =
          i == months.length - 1 &&
          months.length > 1 &&
          months[i] != months[i - 1];
      final label = 'Month ${i + 1}';
      return Semantics(
        label:
            '$label${rounding ? ', takes the rounding' : ''}, '
            '${rsSpoken(months[i])}',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : Space.s12,
            bottom: Space.s12,
          ),
          decoration: i == 0
              ? null
              : BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text.rich(
                  TextSpan(
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(text: label),
                      if (rounding)
                        TextSpan(text: ' · takes the rounding', style: t.tiny),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.s12),
              // Right-aligned; wraps instead of overflowing at large text.
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    rs(months[i]),
                    style: t.h4,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget tile(String value, String label, String spoken) => Expanded(
      child: Semantics(
        label: '$spoken $label',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: Space.s12,
            horizontal: Space.s10,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.note),
          ),
          child: Column(
            children: [
              FigureText(
                value,
                style: t.h4,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.s2),
              Text(label, style: t.tiny, textAlign: TextAlign.center),
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
          if (title != null) ...[
            Semantics(header: true, child: Eyebrow(title!, atomPay: true)),
            Gap.s14,
          ],
          for (var i = 0; i < months.length; i++) month(i),
          Gap.s14,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(rs(plan.advance), 'advance', rsSpoken(plan.advance)),
                const SizedBox(width: Space.s8),
                tile(
                  plan.markup == 0 ? '0%' : rs(plan.markup),
                  'markup',
                  plan.markup == 0 ? 'no' : rsSpoken(plan.markup),
                ),
                const SizedBox(width: Space.s8),
                tile(rs(plan.total), 'in total', rsSpoken(plan.total)),
              ],
            ),
          ),
          Gap.s14,
          FeeDisclaimer(
            percent: plan.processingFeePercent,
            fee: plan.processingFee,
          ),
        ],
      ),
    );
  }
}

/// "A 3% processing fee (Rs. 1,410) is shown with every plan…"
class FeeDisclaimer extends StatelessWidget {
  const new({required this.percent, required this.fee, super.key});

  final num percent;
  final int fee;

  @override
  Widget build(BuildContext context) => Text(
    'A $percent% processing fee (${rs(fee)}) is shown with every plan as a '
    'disclaimer and is not added to the total. Delivery charges apply.',
    style: context.text.tiny.copyWith(height: 1.55),
  );
}
