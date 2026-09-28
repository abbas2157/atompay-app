import 'package:atompay_mobile/core/models/instalment.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/dashboard/data/dashboard_models.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// The colour of the spectrum gradient at [t] (0…1).
Color spectrumAt(double t) {
  final colors = AppColors.spectrum.colors;
  final scaled = t.clamp(0.0, 1.0) * (colors.length - 1);
  final i = scaled.floor().clamp(0, colors.length - 2);
  return Color.lerp(colors[i], colors[i + 1], scaled - i)!;
}

/// A rounded bar filled with the spectrum up to [percent].
class SpectrumBar extends StatelessWidget {
  const new({required this.percent, super.key, this.track});

  final int percent;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent.clamp(0, 100)) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track ?? context.tokens.line),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fraction,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.spectrum),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nucleus card: what's left to spend, then the limit breakdown
/// (handbook §4.6).
class LimitCard extends StatelessWidget {
  const new({required this.limit, super.key});

  final Limit limit;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.darkCard);
    return DecoratedBox(
      // The line border only shows in dark mode, where the card is black on
      // near-black (handbook §4.1).
      decoration: BoxDecoration(
        color: context.tokens.nucleusCard,
        borderRadius: radius,
        border: Border.all(color: context.tokens.line),
      ),
      // A gradient replaces a BoxDecoration's colour, so the soft violet
      // glow sits on its own layer.
      child: Container(
        padding: const EdgeInsets.all(Space.x24),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const RadialGradient(
            center: Alignment(0.9, -1),
            radius: 1.2,
            colors: [Color(0x3362459B), Color(0x00050708)],
          ),
        ),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    const white = AppColors.white;
    final dim = white.withValues(alpha: 0.8);
    final has = limit.hasLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.availableToSpend.toUpperCase(),
          style: text.eyebrow.copyWith(color: dim),
        ),
        const SizedBox(height: Space.x8),
        Text(
          has ? pkr(limit.available) : l10n.limitNotSet,
          style: text.display.copyWith(color: white),
        ),
        if (has) ...[
          const SizedBox(height: Space.x16),
          Semantics(
            label: l10n.limitUsedPercent(limit.usedPercent),
            child: SpectrumBar(
              percent: limit.usedPercent,
              track: white.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: Space.x16),
          _row(context, l10n.limitLabel, pkr(limit.approved)),
          _row(context, l10n.usedLabel, pkr(limit.used)),
          _row(context, l10n.maxInstalmentLabel, pkr(limit.maxInstalment)),
          if (limit.tenure case final months?)
            _row(context, l10n.tenureLabel, l10n.monthsCount(months)),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final style = context.text.figure(
      context.text.body.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
    );
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Text(
                value,
                style: style.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The six stages, top to bottom. The connector is spectrum up to the
/// current stage (handbook §4.6).
class ProcessStepper extends StatelessWidget {
  const new({required this.stages, super.key});

  final List<Stage> stages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = context.text;
    // Stages before the first non-done one get the spectrum connector.
    final reached = stages.indexWhere((s) => s.state != 'done');
    final progress = reached == -1 ? stages.length : reached;
    final last = stages.length - 1;

    return Column(
      children: [
        for (final (i, stage) in stages.indexed)
          MergeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        _Dot(state: stage.state, tokens: t),
                        if (i < last)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: Space.x4,
                              ),
                              decoration: BoxDecoration(
                                color: i < progress ? null : t.line,
                                gradient: i < progress
                                    ? LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          spectrumAt(i / last),
                                          spectrumAt((i + 1) / last),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.x12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < last ? Space.x20 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage.title,
                            style: text.label.copyWith(
                              color: stage.state == 'upcoming'
                                  ? t.muted
                                  : t.ink,
                            ),
                          ),
                          if (stage.hint.isNotEmpty)
                            Text(stage.hint, style: text.bodySmall),
                          // Status in words, not colour alone.
                          Text(
                            _stateLabel(l10n, stage.state),
                            style: text.bodySmall.copyWith(
                              color: _stateColor(stage.state, t),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _stateLabel(AppLocalizations l10n, String state) =>
      switch (state) {
        'done' => l10n.stageDone,
        'current' => l10n.stageCurrent,
        'blocked' => l10n.stageBlocked,
        _ => l10n.stageUpcoming,
      };

  static Color _stateColor(String state, AppTokens t) => switch (state) {
    'done' => AppColors.ok,
    'current' => AppColors.violet,
    'blocked' => AppColors.coral,
    _ => t.muted,
  };
}

class _Dot extends StatelessWidget {
  const new({required this.state, required this.tokens});

  final String state;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final (fill, border, icon) = switch (state) {
      'done' => (AppColors.ok, AppColors.ok, Icons.check),
      'current' => (AppColors.violet, AppColors.violet, null),
      'blocked' => (AppColors.coral, AppColors.coral, Icons.priority_high),
      _ => (tokens.surface, tokens.line, null),
    };
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: icon == null ? null : Icon(icon, size: 14, color: AppColors.white),
    );
  }
}

String instalmentStateLabel(AppLocalizations l10n, String state) =>
    switch (state) {
      'paid' => l10n.instalmentPaid,
      'late' => l10n.instalmentLate,
      'due' => l10n.instalmentDue,
      _ => l10n.instalmentUpcoming,
    };

/// "Thursday, 24 October · PKR 12,500 · Poco C75" with a state pill.
class NextDueCard extends StatelessWidget {
  const new({required this.instalment, super.key, this.onTap});

  final Instalment instalment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final due = Dates.parseDate(instalment.dueDate);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.nextDueTitle.toUpperCase(),
                      style: text.eyebrow,
                    ),
                  ),
                  StatusPill(
                    label: instalmentStateLabel(l10n, instalment.state),
                    tone: StatusTone.fromApi(instalment.state),
                  ),
                ],
              ),
              const SizedBox(height: Space.x12),
              if (due != null) Text(Dates.long(due), style: text.title),
              const SizedBox(height: Space.x4),
              Text(
                [pkr(instalment.amount), ?instalment.productTitle].join(' · '),
                style: text.figure(text.body),
              ),
              Text(instalment.label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
