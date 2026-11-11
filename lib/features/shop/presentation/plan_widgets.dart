import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:flutter/material.dart';

/// The three months, advance, markup and total of a `/plan-preview`, with
/// the processing-fee disclaimer (brief §2). Nothing here is computed.
class PlanBreakdown extends StatelessWidget {
  const new({required this.plan, this.title, super.key});

  final PlanPreview plan;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final months = plan.instalments;
    Widget stat(String value, String label, String spoken) => Expanded(
      child: Semantics(
        label: '$spoken $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(value, style: t.h4),
            Text(label, style: t.tiny),
          ],
        ),
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[Text(title!, style: t.h4), Gap.s12],
          KeyValueList([
            for (var i = 0; i < months.length; i++)
              KeyValue(
                i == months.length - 1 &&
                        months.length > 1 &&
                        months[i] != months[i - 1]
                    ? 'Month ${i + 1} · takes the rounding'
                    : 'Month ${i + 1}',
                rs(months[i]),
                spoken: rsSpoken(months[i]),
              ),
          ]),
          Gap.s12,
          Container(
            padding: const EdgeInsets.symmetric(vertical: Space.s12),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(Radii.row),
            ),
            child: Row(
              children: [
                stat(rs(plan.advance), 'advance', rsSpoken(plan.advance)),
                stat(
                  plan.markup == 0 ? '0%' : rs(plan.markup),
                  'markup',
                  plan.markup == 0 ? 'no' : rsSpoken(plan.markup),
                ),
                stat(rs(plan.total), 'in total', rsSpoken(plan.total)),
              ],
            ),
          ),
          Gap.s12,
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
    style: context.text.small,
  );
}
