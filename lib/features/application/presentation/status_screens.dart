import 'dart:async';
import 'dart:typed_data';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/home/presentation/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Back that never strands the customer: pops when it can, otherwise Home
/// (after "Application sent" the wizard is gone from the stack).
void backOrHome(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.home);

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
    final latest = info.value?.latest;
    final active = info.value?.active;
    final title = switch (latest) {
      Assessment(status: 'pending') when active != null => 'Limit review',
      Assessment(status: 'rejected') when active == null => 'Your application',
      _ => 'KYC & verification',
    };
    return _BackToHome(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppTopBar(
          title: title,
          bottomBorder: true,
          onLeading: () => backOrHome(context),
        ),
        body: AsyncBody(
          value: both,
          loading: const _StatusSkeleton(),
          onRetry: () => _refresh(ref),
          data: (pair) {
            final (p, i) = pair;
            final latest = i.latest;
            Widget body;
            if (latest != null &&
                latest.status == 'rejected' &&
                i.active == null) {
              body = _RejectedView(a: latest);
            } else if (latest != null &&
                latest.status == 'pending' &&
                i.active != null) {
              body = _ReviewPendingView(a: latest, active: i.active!);
            } else {
              body = _KycView(profile: p, info: i);
            }
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
    final verified = profile.status == 'verified';
    final masked = verified;
    final note = switch (latest?.status) {
      'pending' => const Note(
        tone: NoteTone.green,
        icon: Icons.check,
        text:
            'Application received. Our team will verify your address and '
            'confirm your limit.',
      ),
      'approved' || 'conditional' => Note(
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
    final badge = switch (profile.status) {
      'verified' => const AppBadge.green('Verified'),
      'rejected' => const AppBadge.rose('Not verified'),
      'pending' => const AppBadge.amber('Under review'),
      _ => const AppBadge.grey('Not started'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                'Your details',
                action: 'Update',
                onAction: () => context.pushOnce(Routes.applicationStep(1)),
              ),
              Gap.s8,
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
              Gap.s8,
              Text(
                'Your CNIC and mobile are masked once verified.',
                style: t.small,
              ),
            ],
          ),
        ),
        Gap.s14,
        ListGroup(
          title: 'Documents · private to you and our team',
          children: [
            for (final doc in CaptureDoc.values)
              ListRow(
                title: doc.title,
                icon: doc == CaptureDoc.selfie
                    ? Icons.face_outlined
                    : Icons.badge_outlined,
                tileTone: profile.uploaded(doc.key)
                    ? TileTone.green
                    : TileTone.grey,
                summary: profile.uploaded(doc.key)
                    ? (profile.submittedAt == null
                          ? 'Uploaded'
                          : 'Uploaded ${dayMonth(profile.submittedAt!)}')
                    : 'Not uploaded yet',
                onTap: profile.uploaded(doc.key)
                    ? () => context.pushOnce(Routes.document(doc.key))
                    : null,
              ),
          ],
        ),
        Gap.s20,
        AppButton.ghost(
          'Back to home',
          block: true,
          onPressed: () => context.go(Routes.home),
        ),
      ],
    );
  }
}

/// A limit review in progress (canvas "Limit review pending").
class _ReviewPendingView extends StatelessWidget {
  const new({required this.a, required this.active});

  final Assessment a;
  final Assessment active;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: AppBadge.amber('Under review'),
        ),
        Gap.s12,
        if (active.approvedLimit != null) ...[
          Note(
            tone: NoteTone.green,
            text:
                'Your ${rs(active.approvedLimit!)} limit stays active while '
                'we review. You can keep shopping with it.',
          ),
          Gap.s14,
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where it is', style: t.h4),
              Text('Application #${a.id}', style: t.small),
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
        Gap.s8,
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
    final note = a.notes?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: AppBadge.rose('Not approved'),
        ),
        Gap.s12,
        Semantics(
          header: true,
          child: Text("We couldn't approve a limit this time", style: t.h2),
        ),
        Gap.s8,
        Text(
          "This doesn't affect your Atomshop.pk account. You can still shop "
          'there with its other payment options.',
          style: t.lead,
        ),
        Gap.s16,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What our team noted', style: t.h4),
              if (a.decidedAt != null)
                Text('Decided ${dayMonthYear(a.decidedAt!)}', style: t.small),
              Gap.s12,
              Text(
                note == null || note.isEmpty
                    ? 'Our team did not add a note.'
                    : note,
                style: t.body,
              ),
            ],
          ),
        ),
        Gap.s14,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What you can do', style: t.h4),
              Gap.s12,
              const TickList([
                TextSpan(
                  text:
                      'Update your details if something has changed, such as '
                      'your income or your address.',
                ),
                TextSpan(text: "Ask us why if the note doesn't explain it."),
                TextSpan(
                  text:
                      'Disagree with the decision? Raise a complaint and we '
                      'will look at it again.',
                ),
              ], icon: Icons.arrow_forward),
            ],
          ),
        ),
        Gap.s20,
        AppButton.primary(
          'Update my details',
          block: true,
          onPressed: () => context.pushOnce(Routes.applicationStep(1)),
        ),
        Gap.s8,
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
      appBar: const AppTopBar(title: 'My applications', bottomBorder: true),
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
                      Gap.s12,
                    ],
                    Text(
                      'Every application you have made, newest first.',
                      style: context.text.small,
                      textAlign: TextAlign.center,
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

Widget statusBadge(Assessment a) => switch (a.status) {
  'pending' => const AppBadge.amber('Under review'),
  'approved' => const AppBadge.green('Approved'),
  'conditional' => AppBadge.green(a.statusLabel ?? 'Approved'),
  'rejected' => const AppBadge.rose('Not approved'),
  _ => AppBadge.grey(a.statusLabel ?? a.status),
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
      onTap: () => context.pushOnce(Routes.applicationDetail(a.id)),
      semanticLabel:
          '$kind, ${switch (a.status) {
            'pending' => 'under review',
            'rejected' => 'not approved',
            _ => 'approved',
          }}. Application ${a.id}${inForce ? ', in force' : ''}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(kind, style: t.h4)),
              statusBadge(a),
            ],
          ),
          Gap.s12,
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
          Gap.s8,
          Text(
            'Application #${a.id}${inForce ? ' · in force' : ''}',
            style: t.small,
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
        bottomBorder: true,
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
          final Widget body;
          if (a.status == 'pending' && active != null && active.id != a.id) {
            body = _ReviewPendingView(a: a, active: active);
          } else if (a.status == 'rejected') {
            body = _RejectedView(a: a);
          } else {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: statusBadge(a)),
                Gap.s12,
                AppCard(
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

  Future<void> _replace() async {
    final bytes = await context.push<Uint8List>(Routes.capture(widget.doc.key));
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    final flow = ref.read(applyFlowProvider.notifier);
    try {
      await flow.load();
      flow.setPhoto(widget.doc, bytes);
      await flow.saveProfileIfChanged();
      flow.clear();
      ref
        ..invalidate(profileProvider)
        ..invalidate(documentProvider(widget.doc))
        ..invalidate(dashboardProvider);
      showToast('Photo replaced. We will verify it again.');
    } on Object {
      showToast("We couldn't upload the photo. Try again.", error: true);
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
    return SecureScreen(
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppTopBar(
          title: widget.doc.title,
          leading: TopBarLeading.close,
          bottomBorder: true,
        ),
        body: FormPage(
          footer: AppButton.ghost(
            'Replace this photo',
            block: true,
            busy: _busy,
            onPressed: _busy ? null : _replace,
          ),
          children: [
            AspectRatio(
              aspectRatio: widget.doc == CaptureDoc.selfie ? 3 / 4 : 1.586,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: ColoredBox(
                  color: c.ink,
                  child: switch (image) {
                    AsyncData(value: final bytes?) => Semantics(
                      image: true,
                      label: 'Your uploaded ${widget.doc.title}',
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                    AsyncData() => Center(
                      child: Text(
                        'Not uploaded yet',
                        style: t.body.copyWith(color: c.white),
                      ),
                    ),
                    AsyncError(:final error) => ErrorStateView(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(documentProvider(widget.doc)),
                    ),
                    _ => Center(
                      child: Semantics(
                        label: 'Loading your photo',
                        child: CircularProgressIndicator(color: c.white),
                      ),
                    ),
                  },
                ),
              ),
            ),
            Gap.s16,
            Text(
              '${_uploaded(profile)}Shown from the server and never saved '
              'to this phone. '
              'Screenshots are blocked here.',
              style: t.small,
            ),
            Gap.s8,
            Text(
              'Replacing a document sends your identity for verification '
              'again.',
              style: t.small,
            ),
          ],
        ),
      ),
    );
  }
}
