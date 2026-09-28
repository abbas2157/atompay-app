import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/guest_tray.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/domain/application_controllers.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public "What could I get?" (handbook §5.8). Nothing is saved; the result
/// must always say "estimate".
class EstimatorScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EstimatorScreen> createState() => _EstimatorScreenState();
}

class _EstimatorScreenState extends ConsumerState<EstimatorScreen> {
  final _income = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final l10n = context.l10n;
    final income = MoneyInputFormatter.parse(_income.text);
    final error = income == null
        ? l10n.fieldRequired
        : (income < 1000 ? l10n.incomeTooLow : null);
    setState(() => _local = error);
    if (error != null) return;
    FocusScope.of(context).unfocus();
    await ref.read(estimateControllerProvider.notifier).estimate(income!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final status = ref.watch(estimateControllerProvider);
    final result = ref.watch(estimateResultProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.estimatorTitle)),
      // Public screen: sign-in / sign-up stay one tap away for guests.
      bottomNavigationBar: const GuestTray(),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          Text(l10n.estimatorIntro, style: text.body),
          const SizedBox(height: Space.x24),
          MoneyField(
            label: l10n.monthlyIncomeLabel,
            controller: _income,
            textInputAction: TextInputAction.done,
            errorText: _local ?? status.field('monthly_income'),
            onChanged: (_) {
              ref
                  .read(estimateControllerProvider.notifier)
                  .clearField('monthly_income');
              if (_local != null) setState(() => _local = null);
            },
            onSubmitted: (_) => _estimate(),
          ),
          const SizedBox(height: Space.x24),
          SubmitSection(
            status: status,
            label: l10n.estimateButton,
            onPressed: _estimate,
          ),
          if (result != null) ...[
            const SizedBox(height: Space.x24),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(Space.x24),
                decoration: BoxDecoration(
                  color: context.tokens.nucleusCard,
                  borderRadius: BorderRadius.circular(Radii.darkCard),
                  border: Border.all(color: context.tokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.estimatedLimit.toUpperCase(),
                      style: text.eyebrow.copyWith(
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: Space.x8),
                    Text(
                      pkr(result.estimatedLimit),
                      style: text.display.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: Space.x16),
                    Text(
                      '${l10n.estimatedMaxInstalment}: '
                      '${pkr(result.estimatedMaxInstalment)}',
                      style: text.figure(
                        text.body.copyWith(color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.x12),
            // Required wording (handbook §5.8).
            Text(l10n.estimateLabel, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
