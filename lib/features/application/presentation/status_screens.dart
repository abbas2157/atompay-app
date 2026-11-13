import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/application_repository.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/application/data/kyc_status.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/home/presentation/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Back that never strands the customer: pops when it can, otherwise Home
/// (after "Application sent" the wizard is gone from the stack).
void backOrHome(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.home);

/// A status badge at the end of the app bar (canvas `badge u-mr8`).
Widget? _barBadge(Widget? badge) => badge == null
    ? null
    : Padding(
        padding: const EdgeInsets.only(right: Space.s8),
        child: Center(child: badge),
      );

/// Canvas `.card.u-pad`.
const _uPad = EdgeInsets.all(Space.s18);

/// Canvas `.card.u-pad-row`.
const _uPadRow = EdgeInsets.symmetric(
  horizontal: Space.s18,
  vertical: Space.s16,
);

class _BackToHome extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(Routes.home);
    },
    child: child,
  );
}

// ---- KYC and verification ---------------------------------------------------

/// Where the application stands (canvas "KYC and verification"; a pending
/// limit review or a rejection shows those boards instead).
class VerificationScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(profileProvider)
      ..invalidate(applicationInfoProvider)
      ..invalidate(dashboardProvider);
    try {
      await ref.read(applicationInfoProvider.future);
    } on Object {
      // Shown by the error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final info = ref.watch(applicationInfoProvider);
    final both = switch ((profile, info)) {
      (AsyncData(value: final p), AsyncData(value: final i)) => AsyncData((
        p,
        i,
      )),
      (AsyncError(:final error, :final stackTrace), _) ||
      (
        _,
        AsyncError(:final error, :final stackTrace),
      ) => AsyncError<(Profile, ApplicationInfo)>(error, stackTrace),
      _ => const AsyncLoading<(Profile, ApplicationInfo)>(),
    };
    final view = applicationView(
      info.value?.latest,
      active: info.value?.active,
    );
    final title = switch (view) {
      ApplicationView.review => 'Limit review',
      ApplicationView.rejected => 'Your application',
      ApplicationView.standard => 'KYC & verification',
    };
    // Canvas: the review and rejection boards carry their status in the bar.
    final barBadge = switch (view) {
      ApplicationView.review => const AppBadge.amber('Under review'),
      ApplicationView.rejected => const AppBadge.rose('Not approved'),
      ApplicationView.standard => null,
    };
    return _BackToHome(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppTopBar(
          title: title,
          onLeading: () => backOrHome(context),
          actions: [?_barBadge(barBadge)],
        ),
        body: AsyncBody(
          value: both,
          loading: const _StatusSkeleton(),
          onRetry: () => _refresh(ref),
          data: (pair) {
            final (p, i) = pair;
            final latest = i.latest;
            final body = switch (applicationView(latest, active: i.active)) {
              ApplicationView.rejected => _RejectedView(a: latest!),
              ApplicationView.review => _ReviewPendingView(
                a: latest!,
                active: i.active!,
              ),
              ApplicationView.standard => _KycView(profile: p, info: i),
            };
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.all(Space.gutter),
                children: [body],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KycView extends ConsumerWidget {
  const new({required this.profile, required this.info});

  final Profile profile;
  final ApplicationInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final stages = ref.watch(dashboardProvider).value?.data.stages ?? [];
    final latest = info.latest;
    final verified = profile.kyc == KycStatus.verified;
    final masked = verified;
    final note = switch (latest?.decision) {
      AssessmentStatus.pending => const Note(
        tone: NoteTone.green,
        icon: Icons.check,
        text:
            'Application received. Our team will verify your address and '
            'confirm your limit.',
      ),
      AssessmentStatus.approved || AssessmentStatus.conditional => Note(
        tone: NoteTone.green,
        icon: Icons.check,
        text: latest!.approvedLimit == null
            ? 'Your limit is approved.'
            : 'Your limit of ${rs(latest.approvedLimit!)} is approved.',
      ),
      null when !profile.submitted => Note(
        tone: NoteTone.amber,
        text: 'You haven’t sent your details yet.',
        action: TextLink(
          'Apply for your limit',
          onPressed: () => context.pushOnce(Routes.applicationStep(1)),
        ),
      ),
      _ => null,
    };
    final badge = switch (profile.kyc) {
      KycStatus.verified => const AppBadge.green('Verified'),
      KycStatus.rejected => const AppBadge.rose('Not verified'),
      KycStatus.pending => const AppBadge.amber('Under review'),
      KycStatus.notStarted => const AppBadge.grey('Not started'),
    };
    String cnic() {
      final f = Pk.formatCnic(profile.cnic ?? '');
      if (!masked || f.length != 15) return f;
      return '${f.substring(0, 6)}•••••••${f.substring(13)}';
    }

    String mobile() {
      final m = Pk.formatMobile(profile.mobile ?? '');
      if (!masked || m.length != 12) return m;
      return '${m.substring(0, 5)}•••${m.substring(8)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note != null) ...[note, Gap.s14],
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Where you are', style: t.h4)),
                  badge,
                ],
              ),
              Gap.s14,
              if (stages.isEmpty)
                const SkeletonCard(lines: 4)
              else
                StagesTrack(stages: stages),
            ],
          ),
        ),
        Gap.s14,
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The 48 dp link row already gives the canvas's 12 below.
              SectionHeader(
                'Your details',
                action: 'Update',
                onAction: () => context.pushOnce(Routes.applicationStep(1)),
              ),
              KeyValueList([
                KeyValue('Name', profile.fullName ?? ''),
                KeyValue('CNIC', cnic()),
                KeyValue('Mobile', mobile()),
                KeyValue(
                  'City · Area',
                  [?profile.city?.name, ?profile.area?.name].join(' · '),
                ),
                KeyValue('Address', profile.residentialAddress ?? ''),
              ]),
              Gap.s10,
              Text(
                'Your CNIC and mobile are masked once verified.',
                style: t.tiny.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        Gap.s14,
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.s12,
                runSpacing: Space.s4,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Documents', style: t.h4),
                  ),
                  Text('Private to you and our team', style: t.tiny),
                ],
              ),
              Gap.s12,
              _DocGrid(profile: profile),
            ],
          ),
        ),
        Gap.s14,
        AppButton.ghost(
          'Back to home',
          block: true,
          onPressed: () => context.go(Routes.home),
        ),
      ],
    );
  }
}

/// Canvas `.dg`: the three documents as tiles, three across (stacked when
/// text is large).
class _DocGrid extends StatelessWidget {
  const new({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final doc in CaptureDoc.values) _DocTile(doc: doc, profile: profile),
    ];
    if (TwoUp.stacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) Gap.s8,
            tiles[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.s8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  const new({required this.doc, required this.profile});

  final CaptureDoc doc;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final uploaded = profile.uploaded(doc.key);
    final name = doc == CaptureDoc.selfie ? 'Selfie' : doc.title;
    final status = !uploaded
        ? 'Not uploaded yet'
        : (profile.submittedAt == null
              ? 'Uploaded'
              : 'Uploaded ${dayMonth(profile.submittedAt!)}');
    final radius = BorderRadius.circular(Radii.note);
    return Pressable(
      onTap: uploaded ? () => context.pushOnce(Routes.document(doc.key)) : null,
      scaleOnPress: false,
      borderRadius: radius,
      pressedColor: c.primarySoft,
      semanticLabel: '$name, $status',
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s6,
          vertical: Space.s12,
        ),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: radius,
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (doc) {
                CaptureDoc.cnicFront => Icons.badge_outlined,
                CaptureDoc.cnicBack => Icons.credit_card_outlined,
                CaptureDoc.selfie => Icons.person_outline,
              },
              size: 22,
              color: c.body,
            ),
            Gap.s6,
            Text(
              name,
              textAlign: TextAlign.center,
              style: t.small.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            Gap.s6,
            Text(
              status,
              textAlign: TextAlign.center,
              style: t.xs.copyWith(
                color: uploaded ? c.green : c.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A limit review in progress (canvas "Limit review pending").
class _ReviewPendingView extends ConsumerWidget {
  const new({required this.a, required this.active});

  final Assessment a;
  final Assessment active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    // The server's estimate from the declared income (never derived here).
    final estimate = a.monthlyIncome >= 1000
        ? ref.watch(estimateProvider(a.monthlyIncome)).value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.approvedLimit != null) ...[
          Note(
            tone: NoteTone.green,
            spans: [
              const TextSpan(text: 'Your '),
              TextSpan(
                text: rs(active.approvedLimit!),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const TextSpan(
                text:
                    ' limit stays active while we review — you can keep '
                    'shopping with it.',
              ),
            ],
          ),
          Gap.s14,
        ],
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.s12,
                runSpacing: Space.s4,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Where it is', style: t.h4),
                  ),
                  Text('Application #${a.id}', style: t.tiny),
                ],
              ),
              Gap.s14,
              Track([
                TrackStep(
                  title: 'Review requested',
                  hint: a.submittedAt == null
                      ? null
                      : dayMonthYear(a.submittedAt!),
                  state: TrackState.done,
                ),
                const TrackStep(
                  title: 'Risk assessment',
                  hint: 'Reviewed by AtomPay',
                  state: TrackState.now,
                ),
                const TrackStep(
                  title: 'New limit decided',
                  hint: "We'll notify you and update Home",
                  state: TrackState.upcoming,
                ),
              ]),
            ],
          ),
        ),
        Gap.s14,
        _ToldUs(a: a, canChange: true),
        if (estimate != null) ...[
          Gap.s14,
          ProvisionalLimitCard(
            label: 'Provisional limit',
            limit: estimate.estimatedLimit,
            monthlyCap: estimate.estimatedMaxInstalment,
          ),
        ],
      ],
    );
  }
}

/// "What you told us": the figures as sent, and the server's disposable
/// income.
class _ToldUs extends StatelessWidget {
  const new({required this.a, required this.canChange});

  final Assessment a;
  final bool canChange;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: _uPad,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'What you told us',
          action: canChange ? 'Change' : null,
          onAction: canChange
              ? () => context.pushOnce(Routes.applicationStep(3))
              : null,
        ),
        // The 48 dp link row already leaves the canvas's 12 below it.
        if (!canChange) Gap.s12,
        KeyValueList([
          KeyValue(
            'Work',
            [
              ?(a.employmentStatusLabel ?? a.employmentStatus),
              if ((a.employerName ?? '').isNotEmpty) a.employerName!,
            ].join(' · '),
          ),
          KeyValue(
            'Income',
            '${rs(a.monthlyIncome)} a month',
            spoken: '${rsSpoken(a.monthlyIncome)} a month',
          ),
          KeyValue(
            'Instalments',
            rs(a.existingInstalments),
            spoken: rsSpoken(a.existingInstalments),
          ),
          KeyValue(
            'Expenses',
            rs(a.monthlyExpenses),
            spoken: rsSpoken(a.monthlyExpenses),
          ),
          if (a.disposableIncome != null)
            KeyValue(
              'Disposable',
              rs(a.disposableIncome!),
              spoken: rsSpoken(a.disposableIncome!),
            ),
        ]),
      ],
    ),
  );
}

/// "Application not approved".
class _RejectedView extends StatelessWidget {
  const new({required this.a});

  final Assessment a;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final note = a.notes?.trim();
    TextSpan lead(String bold, String rest) => TextSpan(
      children: [
        TextSpan(
          text: bold,
          style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
        ),
        TextSpan(text: rest),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text("We couldn't approve a limit this time", style: t.h2),
        ),
        Gap.s6,
        Text(
          "This doesn't affect your Atomshop.pk account. You can still shop "
          'there with its other payment options.',
          style: t.small,
        ),
        Gap.s16,
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.s12,
                runSpacing: Space.s4,
                children: [
                  Semantics(
                    header: true,
                    child: Text('What our team noted', style: t.h4),
                  ),
                  if (a.decidedAt != null)
                    Text(
                      'Decided ${dayMonthYear(a.decidedAt!)}',
                      style: t.tiny,
                    ),
                ],
              ),
              Gap.s10,
              // Canvas `.quote`: the reviewer's words, set apart.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s16,
                  vertical: Space.s14,
                ),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.note),
                ),
                child: Text(
                  note == null || note.isEmpty
                      ? 'Our team did not add a note.'
                      : note,
                  style: t.base.copyWith(color: c.ink, height: 1.55),
                ),
              ),
            ],
          ),
        ),
        Gap.s16,
        AppCard(
          padding: _uPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('What you can do', style: t.h4),
              ),
              Gap.s12,
              TickList(
                [
                  lead(
                    'Update your details',
                    ' if something has changed, such as your income or your '
                        'address.',
                  ),
                  lead('Ask us why', " if the note doesn't explain it."),
                  lead(
                    'Disagree with the decision?',
                    ' Raise a complaint and we will look at it again.',
                  ),
                ],
                icons: const [
                  Icons.edit_outlined,
                  Icons.chat_bubble_outline,
                  Icons.shield_outlined,
                ],
                color: c.primary,
              ),
            ],
          ),
        ),
        Gap.s16,
        AppButton.primary(
          'Update my details',
          block: true,
          onPressed: () => context.pushOnce(Routes.applicationStep(1)),
        ),
        Gap.s16,
        AppButton.ghost(
          'Raise a complaint',
          block: true,
          onPressed: () => context.pushOnce(Routes.complaint),
        ),
      ],
    );
  }
}

class _StatusSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const LoadingShape(
    label: 'Loading your application',
    child: Padding(
      padding: EdgeInsets.all(Space.gutter),
      child: Column(
        children: [
          SkeletonCard(lines: 5),
          Gap.s14,
          SkeletonCard(lines: 4),
          Gap.s14,
          SkeletonCard(),
        ],
      ),
    ),
  );
}

// ---- history ----------------------------------------------------------------

/// "My applications", newest first.
class ApplicationHistoryScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(applicationHistoryProvider);
    final activeId = ref.watch(applicationInfoProvider).value?.active?.id;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const AppTopBar(title: 'My applications'),
      body: AsyncBody(
        value: history,
        loading: const _StatusSkeleton(),
        onRetry: () => ref.invalidate(applicationHistoryProvider),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(applicationHistoryProvider)
              ..invalidate(applicationInfoProvider);
            try {
              await ref.read(applicationHistoryProvider.future);
            } on Object {
              // The error state covers it.
            }
          },
          child: list.isEmpty
              ? LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: box.maxHeight,
                      child: StateView(
                        icon: Icons.description_outlined,
                        title: 'No applications yet',
                        body: 'Apply once and every decision shows here.',
                        actions: [
                          AppButton.primary(
                            'Apply for your limit',
                            block: true,
                            onPressed: () =>
                                context.pushOnce(Routes.applicationStep(1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(Space.gutter),
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      _HistoryCard(
                        a: list[i],
                        kind: kindOf(list, i),
                        inForce: list[i].id == activeId,
                      ),
                      Gap.s16,
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s16,
                        vertical: Space.s4,
                      ),
                      child: Text(
                        'Every application you have made, newest first.',
                        style: context.text.tiny.copyWith(height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "First application", "Limit review" (an earlier one was approved) or
/// "Application".
String kindOf(List<Assessment> newestFirst, int i) {
  if (i == newestFirst.length - 1) return 'First application';
  final older = newestFirst.sublist(i + 1);
  return older.any((a) => a.isUsable) ? 'Limit review' : 'Application';
}

Widget statusBadge(Assessment a) => switch (a.decision) {
  AssessmentStatus.pending => const AppBadge.amber('Under review'),
  AssessmentStatus.approved => const AppBadge.green('Approved'),
  AssessmentStatus.conditional => AppBadge.green(a.statusLabel ?? 'Approved'),
  AssessmentStatus.rejected => const AppBadge.rose('Not approved'),
  AssessmentStatus.unknown => AppBadge.grey(a.statusLabel ?? a.status),
};

class _HistoryCard extends StatelessWidget {
  const new({required this.a, required this.kind, required this.inForce});

  final Assessment a;
  final String kind;
  final bool inForce;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final decided = a.decidedAt != null;
    return AppCard(
      padding: _uPadRow,
      onTap: () => context.pushOnce(Routes.applicationDetail(a.id)),
      semanticLabel:
          '$kind, ${switch (a.decision) {
            AssessmentStatus.pending => 'under review',
            AssessmentStatus.rejected => 'not approved',
            AssessmentStatus.approved || AssessmentStatus.conditional => 'approved',
            AssessmentStatus.unknown => (a.statusLabel ?? a.status).toLowerCase(),
          }}. Application ${a.id}${inForce ? ', in force' : ''}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kind,
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Space.s10),
              statusBadge(a),
            ],
          ),
          Gap.s10,
          KeyValueList([
            if (decided)
              KeyValue('Decided', dayMonthYear(a.decidedAt!))
            else if (a.submittedAt != null)
              KeyValue('Submitted', dayMonthYear(a.submittedAt!)),
            if (a.approvedLimit != null)
              KeyValue(
                'Limit',
                rs(a.approvedLimit!),
                spoken: rsSpoken(a.approvedLimit!),
              ),
            if (a.maxInstalment != null)
              KeyValue(
                'Monthly cap',
                rs(a.maxInstalment!),
                spoken: rsSpoken(a.maxInstalment!),
              ),
            if (!decided)
              KeyValue(
                'Declared income',
                rs(a.monthlyIncome),
                spoken: rsSpoken(a.monthlyIncome),
              ),
          ]),
          Gap.s10,
          Text(
            'Application #${a.id}${inForce ? ' · in force' : ''}',
            style: t.tiny,
          ),
        ],
      ),
    );
  }
}

/// One application from the history.
class ApplicationDetailScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(applicationHistoryProvider);
    final info = ref.watch(applicationInfoProvider).value;
    final a = history.value?.where((x) => x.id == id).firstOrNull;
    final t = context.text;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppTopBar(
        title: a == null
            ? 'Application'
            : kindOf(history.value!, history.value!.indexOf(a)),
        // The status sits in the bar, as on the canvas status boards.
        actions: [?_barBadge(a == null ? null : statusBadge(a))],
      ),
      body: AsyncBody(
        value: history,
        loading: const _StatusSkeleton(),
        onRetry: () => ref.invalidate(applicationHistoryProvider),
        notFound: "We can't find this application",
        data: (_) {
          if (a == null) {
            return const StateView(
              icon: Icons.search_off,
              title: "We can't find this application",
            );
          }
          final active = info?.active;
          final view = applicationView(a, active: active, inHistory: true);
          final Widget body;
          if (view == ApplicationView.review) {
            body = _ReviewPendingView(a: a, active: active!);
          } else if (view == ApplicationView.rejected) {
            body = _RejectedView(a: a);
          } else {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: _uPad,
                  child: KeyValueList([
                    KeyValue('Application', '#${a.id}'),
                    if (a.submittedAt != null)
                      KeyValue('Submitted', dayMonthYear(a.submittedAt!)),
                    if (a.decidedAt != null)
                      KeyValue('Decided', dayMonthYear(a.decidedAt!)),
                    if (a.approvedLimit != null)
                      KeyValue(
                        'Limit',
                        rs(a.approvedLimit!),
                        spoken: rsSpoken(a.approvedLimit!),
                      ),
                    if (a.maxInstalment != null)
                      KeyValue(
                        'Monthly cap',
                        rs(a.maxInstalment!),
                        spoken: rsSpoken(a.maxInstalment!),
                      ),
                    if (a.approvedTenure != null)
                      KeyValue('Months', '${a.approvedTenure}'),
                  ]),
                ),
                if ((a.notes ?? '').isNotEmpty) ...[
                  Gap.s14,
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What our team noted', style: t.h4),
                        Gap.s8,
                        Text(a.notes!, style: t.body),
                      ],
                    ),
                  ),
                ],
                Gap.s14,
                _ToldUs(a: a, canChange: false),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Space.gutter),
            children: [body],
          );
        },
      ),
    );
  }
}

String _uploaded(Profile? p) =>
    p?.submittedAt == null ? '' : 'Uploaded ${dayMonth(p!.submittedAt!)}. ';

// ---- document viewer --------------------------------------------------------

/// One identity photo, streamed from the server into memory and never
/// saved (canvas "CNIC front"). Screenshots are blocked.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const new({required this.doc, super.key});

  final CaptureDoc doc;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  bool _busy = false;

  /// Why the last upload failed, shown above the buttons.
  String? _problem;

  /// A photo that didn't go through for a reason other than the photo
  /// itself (the scan was down, no connection): kept for Try again so the
  /// customer needn't retake it.
  Uint8List? _pending;

  Future<void> _replace() async {
    final bytes = await context.push<Uint8List>(Routes.capture(widget.doc.key));
    if (bytes == null || !mounted) return;
    await _upload(bytes);
  }

  Future<void> _upload(Uint8List bytes) async {
    setState(() {
      _busy = true;
      _problem = null;
      _pending = null;
    });
    // Straight to the profile, never through the apply draft: a draft the
    // customer has open elsewhere keeps its edits and isn't sent.
    try {
      final profile = await ref.read(profileProvider.future);
      await ref
          .read(applicationRepositoryProvider)
          .saveProfile(
            profileInputOnFile(profile),
            photos: {widget.doc: bytes},
          );
      ref
        ..invalidate(profileProvider)
        ..invalidate(documentProvider(widget.doc))
        ..invalidate(dashboardProvider);
      showToast('Photo replaced. We will verify it again.');
    } on CheckUnavailable catch (e) {
      _problem = e.message;
      _pending = bytes;
    } on Validation catch (e) {
      // Refused ("This file can't be accepted…"): a new photo is needed.
      _problem = e.first(widget.doc.key) ?? e.message;
    } on Object {
      _problem = "We couldn't upload the photo. Please try again.";
      _pending = bytes;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final image = ref.watch(documentProvider(widget.doc));
    final profile = ref.watch(profileProvider).value;
    final onDark = TextStyle(color: c.white);
    // Canvas: a dark viewer, like the camera, so the photo stands out.
    return SecureScreen(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: c.cam,
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: Sizes.appBar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s8),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.close,
                          size: 22,
                          label: 'Close',
                          color: c.white,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: Space.s6),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.doc.title,
                              style: t.h4.merge(onDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      child: AspectRatio(
                        aspectRatio: widget.doc == CaptureDoc.selfie
                            ? 3 / 4
                            : 1.58,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.note),
                          child: ColoredBox(
                            color: c.ink2,
                            child: switch (image) {
                              AsyncData(value: final bytes?) => Semantics(
                                image: true,
                                label: 'Your uploaded ${widget.doc.title}',
                                child: Image.memory(bytes, fit: BoxFit.contain),
                              ),
                              AsyncData() => Center(
                                child: Text(
                                  'Not uploaded yet',
                                  textAlign: TextAlign.center,
                                  style: t.small.copyWith(
                                    color: c.onDark2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              AsyncError(:final error) => ErrorStateView(
                                error: error,
                                onRetry: () => ref.invalidate(
                                  documentProvider(widget.doc),
                                ),
                              ),
                              _ => Center(
                                child: Semantics(
                                  label: 'Loading your photo',
                                  child: CircularProgressIndicator(
                                    color: c.white,
                                  ),
                                ),
                              ),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.s16,
                    Space.gutter,
                    Space.s24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s14,
                          vertical: Space.s12,
                        ),
                        decoration: BoxDecoration(
                          color: c.ink2,
                          borderRadius: BorderRadius.circular(Radii.note),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: Space.s2),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: c.greenOnDark,
                              ),
                            ),
                            const SizedBox(width: Space.s10),
                            Expanded(
                              child: Text(
                                '${_uploaded(profile)}Shown from the server '
                                'and never saved to this phone. Screenshots '
                                'are blocked here.',
                                style: t.small.copyWith(color: c.onDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_problem != null) ...[
                        Gap.s12,
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _problem!,
                            textAlign: TextAlign.center,
                            style: t.small.copyWith(
                              color: c.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (_pending != null) ...[
                        Gap.s12,
                        AppButton.primary(
                          'Try again',
                          block: true,
                          busy: _busy,
                          onPressed: _busy ? null : () => _upload(_pending!),
                        ),
                      ],
                      Gap.s12,
                      AppButton.ghost(
                        _pending != null || _problem == null
                            ? 'Replace this photo'
                            : 'Take a new photo',
                        block: true,
                        busy: _busy && _pending == null,
                        onPressed: _busy ? null : _replace,
                      ),
                      Gap.s12,
                      Text(
                        'Replacing a document sends your identity for '
                        'verification again.',
                        textAlign: TextAlign.center,
                        style: t.tiny.copyWith(color: c.onDark2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
