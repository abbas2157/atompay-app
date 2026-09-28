import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/core/widgets/value_row.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/domain/application_controllers.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The latest assessment: what was declared and, once decided, the outcome
/// (handbook §5.8).
class ApplicationStatusScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(applicationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.applicationTitle),
        actions: [
          IconButton(
            tooltip: l10n.historyTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push(Routes.applicationHistory),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(applicationProvider.future),
        child: switch (overview) {
          AsyncValue(:final value?) => _Body(value),
          AsyncError(:final error) => ListView(
            children: [
              MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(applicationProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const new(this.overview);

  final ApplicationOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final latest = overview.latest;

    if (latest == null) {
      return ListView(
        children: [
          MessageView(
            message: l10n.noApplicationYet,
            actionLabel: l10n.applyNow,
            onAction: () => context.pushReplacement(Routes.application),
          ),
        ],
      );
    }

    final active = overview.active;
    final reviewingNew =
        active != null && active.id != latest.id && latest.status == 'pending';

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        AssessmentCard(assessment: latest),
        if (reviewingNew) ...[
          const SizedBox(height: Space.x16),
          AppBanner(tone: StatusTone.info, title: l10n.reapplyNote),
        ],
        const SizedBox(height: Space.x24),
        GhostButton(
          label: l10n.updateIncome,
          onPressed: () => context.push(Routes.application),
        ),
      ],
    );
  }
}

/// One assessment: status, what was declared and (once decided) the
/// outcome with the staff note.
class AssessmentCard extends StatelessWidget {
  const new({required this.assessment, super.key, this.compact = false});

  final Assessment assessment;

  /// History list: status, dates and outcome only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final a = assessment;
    final decided = a.status != 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.x20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  // Prefer our wording; the server label covers new values.
                  label: switch (a.status) {
                    'pending' ||
                    'approved' ||
                    'conditional' ||
                    'rejected' => applicationStatusLabel(l10n, a.status),
                    _ => a.statusLabel,
                  },
                  tone: StatusTone.fromApi(a.status),
                ),
              ],
            ),
            const SizedBox(height: Space.x8),
            if (a.submittedAt case final at?)
              Text(l10n.submittedOn(Dates.short(at)), style: text.bodySmall),
            if (a.decidedAt case final at?)
              Text(l10n.decidedOn(Dates.short(at)), style: text.bodySmall),
            if (!compact) ...[
              const SizedBox(height: Space.x16),
              Text(l10n.declaredTitle.toUpperCase(), style: text.eyebrow),
              ValueRow(
                label: l10n.employmentStatusLabel,
                value: a.employmentStatusLabel,
              ),
              if (a.employerName case final name? when name.isNotEmpty)
                ValueRow(label: l10n.employerLabel, value: name),
              ValueRow(
                label: l10n.incomeSourceLabel,
                value: a.incomeSourceLabel,
              ),
              ValueRow(
                label: l10n.monthlyIncomeLabel,
                value: pkr(a.monthlyIncome),
              ),
              ValueRow(
                label: l10n.existingInstalmentsLabel,
                value: pkr(a.existingInstalments),
              ),
              ValueRow(
                label: l10n.monthlyExpensesLabel,
                value: pkr(a.monthlyExpenses),
              ),
              ValueRow(
                label: l10n.disposableIncomeLabel,
                value: pkr(a.disposableIncome),
              ),
            ],
            if (decided) ...[
              const SizedBox(height: Space.x16),
              Text(l10n.decisionTitle.toUpperCase(), style: text.eyebrow),
              if (a.approvedLimit case final v?)
                ValueRow(label: l10n.approvedLimitLabel, value: pkr(v)),
              if (a.maxInstalment case final v?)
                ValueRow(label: l10n.maxInstalmentLabel, value: pkr(v)),
              if (a.approvedTenure case final v?)
                ValueRow(label: l10n.tenureLabel, value: l10n.monthsCount(v)),
            ],
            if (a.notes case final notes? when notes.isNotEmpty) ...[
              const SizedBox(height: Space.x12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.x12),
                decoration: BoxDecoration(
                  color: context.tokens.paper,
                  borderRadius: BorderRadius.circular(Radii.input),
                  border: Border.all(color: context.tokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.notesLabel.toUpperCase(), style: text.eyebrow),
                    const SizedBox(height: Space.x4),
                    Text(notes, style: text.body),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `GET /application/history`, newest first.
class ApplicationHistoryScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(applicationHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(applicationHistoryProvider.future),
        child: switch (history) {
          AsyncValue(:final value?) when value.isEmpty => ListView(
            children: [MessageView(message: l10n.noHistory)],
          ),
          AsyncValue(:final value?) => ListView.separated(
            padding: const EdgeInsets.all(Space.gutter),
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x12),
            itemBuilder: (_, i) =>
                AssessmentCard(assessment: value[i], compact: true),
          ),
          AsyncError(:final error) => ListView(
            children: [
              MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(applicationHistoryProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
