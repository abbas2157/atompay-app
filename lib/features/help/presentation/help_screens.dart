import 'dart:async';
import 'dart:math' as math;

import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/picker.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/help/application/complaint_controller.dart';
import 'package:atompay_mobile/features/help/data/complaints_repository.dart';
import 'package:atompay_mobile/features/help/data/help_content.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/launch/data/config_repository.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shown in rose while `/app-config.business` lacks the fact (set in
/// Atomshop's admin panel).
abstract final class HelpPlaceholders {
  static const responseTime = '[RESPONSE TIME]';
}

/// Help centre (canvas "Help"): Ask Atom, topics, common questions, and
/// Talk to us.
class HelpScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final c = context.colors;
    final support = ref.watch(appConfigProvider).support;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.surface,
        body: Column(
          children: [
            const _HelpHeader(),
            Expanded(
              // Canvas `.content{gap:20px}`.
              child: FormPage(
                children: [
                  const AskAtomCard(
                    subtitle: 'Fastest: it knows your limit and your orders',
                    avatarSize: 46,
                    chevronRose: true,
                  ),
                  Gap.s20,
                  const SectionLabel('Topics'),
                  const _TopicGrid(),
                  Gap.s20,
                  ListGroup(
                    title: 'Common questions',
                    children: [
                      for (final (key, q) in HelpContent.common)
                        ListRow(
                          title: q.question,
                          summary: HelpContent.topic(key)!.title,
                          onTap: () =>
                              context.pushOnce(Routes.helpQuestion(key, q.id)),
                        ),
                      Pressable(
                        onTap: () =>
                            context.pushOnce(Routes.helpTopic(HelpContent.all)),
                        scaleOnPress: false,
                        borderRadius: BorderRadius.zero,
                        pressedColor: c.primarySoft,
                        semanticLabel: 'All questions',
                        excludeChildSemantics: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 60),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.s16,
                              vertical: Space.s12,
                            ),
                            child: Center(
                              child: Text(
                                'All questions',
                                textAlign: TextAlign.center,
                                style: t.body.copyWith(
                                  color: c.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap.s20,
                  ListGroup(
                    title: 'Talk to us',
                    children: [
                      ListRow(
                        title: 'Raise a complaint',
                        summary: 'A person reads every one',
                        icon: Icons.gpp_maybe_outlined,
                        tileTone: TileTone.rose,
                        onTap: () => context.pushOnce(Routes.complaint),
                      ),
                      ..._contactRows(support),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A row whose value is null is hidden (brief §9).
  static List<Widget> _contactRows(Support s) => [
    if (s.whatsapp case final w?)
      ListRow(
        title: 'WhatsApp',
        summary: w,
        icon: Icons.chat_outlined,
        tileTone: TileTone.green,
        external: true,
        onTap: () => unawaited(Links.whatsapp(w)),
      ),
    if (s.phone case final p?)
      ListRow(
        title: 'Call',
        summary: p,
        icon: Icons.call_outlined,
        tileTone: TileTone.grey,
        external: true,
        onTap: () => unawaited(Links.call(p)),
      ),
    if (s.email case final e?)
      ListRow(
        title: 'Email',
        summary: e,
        icon: Icons.mail_outline,
        tileTone: TileTone.grey,
        external: true,
        onTap: () => unawaited(Links.email(e)),
      ),
  ];
}

/// Canvas `.htop`: the ink band with a white back button, the heading and
/// the search pill.
class _HelpHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return ColoredBox(
      color: c.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.s20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(-Space.s8, 0),
                    child: AppIconButton(
                      icon: Icons.chevron_left,
                      size: 28,
                      label: 'Back',
                      color: c.white,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: Space.s6),
                  Semantics(
                    header: true,
                    child: Text(
                      'How can we help?',
                      style: t.h1b.copyWith(color: c.white),
                    ),
                  ),
                  const SizedBox(height: Space.s14),
                  Pressable(
                    onTap: () => context.pushOnce(
                      Routes.helpTopicSearch(HelpContent.all),
                    ),
                    scaleOnPress: false,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    semanticLabel: 'Search help',
                    excludeChildSemantics: true,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s16,
                        vertical: Space.s6,
                      ),
                      decoration: BoxDecoration(
                        color: c.white,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 18, color: c.muted),
                          const SizedBox(width: Space.s10),
                          Expanded(
                            child: Text(
                              'Search: "limit", "late payment"…',
                              style: t.body.copyWith(color: c.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

/// Canvas `.topics`: three columns, 8 apart; tiles in a row share a height
/// so large text grows them together.
class _TopicGrid extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    const topics = HelpContent.topics;
    return Column(
      children: [
        for (var r = 0; r < topics.length; r += 3) ...[
          if (r > 0) Gap.s8,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = r; i < r + 3; i++) ...[
                  if (i > r) const SizedBox(width: Space.s8),
                  Expanded(
                    child: i < topics.length
                        ? _TopicTile(
                            topic: topics[i],
                            onTap: () => context.pushOnce(
                              Routes.helpTopic(topics[i].key),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const new({required this.topic, required this.onTap});

  final HelpTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.row),
      pressedColor: c.primarySoft,
      semanticLabel: topic.title,
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s4,
          vertical: Space.s14,
        ),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(Radii.row),
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTile(topic.icon, tone: topic.tone, size: 38),
            Gap.s8,
            Text(
              topic.title,
              textAlign: TextAlign.center,
              style: context.text.small.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wash card that opens Ask Atom.
class AskAtomCard extends StatelessWidget {
  const new({
    required this.subtitle,
    this.title = 'Ask Atom',
    this.avatarSize = 44,
    this.chevronRose = false,
    super.key,
  });

  final String title;
  final String subtitle;

  /// 46 on Help, 44 under a topic.
  final double avatarSize;

  /// Help's card has a rose chevron; elsewhere it is the usual glyph.
  final bool chevronRose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return AppCard(
      color: c.apayWash,
      borderColor: c.apayLine,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s14,
      ),
      onTap: () => context.pushOnce(Routes.atom),
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          AtomAvatar(size: avatarSize),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: t.small.copyWith(color: c.body)),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: chevronRose ? c.rose : c.glyph,
          ),
        ],
      ),
    );
  }
}

/// One topic with expandable answers; `all` lists every question with a
/// search box (canvas "Help topic"). The search box is on every topic: a
/// query there searches all of Help.
class HelpTopicScreen extends StatefulWidget {
  const new({
    required this.topic,
    this.question,
    this.search = false,
    super.key,
  });

  final String topic;

  /// The question to open expanded.
  final String? question;

  /// Opened from Help's search box: focus the search field.
  final bool search;

  @override
  State<HelpTopicScreen> createState() => _HelpTopicScreenState();
}

class _HelpTopicScreenState extends State<HelpTopicScreen> {
  final _query = TextEditingController();
  late String? _open = widget.question;

  bool get _isAll => widget.topic == HelpContent.all;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final topic = HelpContent.topic(widget.topic);
    final title = _isAll ? 'All questions' : (topic?.title ?? 'Help');
    final searching = normaliseQuery(_query.text).isNotEmpty;
    final items = _isAll || searching
        ? HelpContent.search(_query.text)
        : [for (final q in topic?.questions ?? <HelpQuestion>[]) (topic!, q)];

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppTopBar(title: title),
      body: FormPage(
        children: [
          FocusRing(
            builder: ({required focused}) => TextField(
              controller: _query,
              autofocus: widget.search,
              textInputAction: TextInputAction.search,
              style: t.body,
              decoration: InputDecoration(
                hintText: 'Search help',
                fillColor: focused ? c.white : c.field,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(
                    left: Space.s14,
                    right: Space.s10,
                  ),
                  child: Icon(Icons.search, size: 18, color: c.muted),
                ),
                prefixIconConstraints: const BoxConstraints(),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : AppIconButton(
                        icon: Icons.close,
                        label: 'Clear search',
                        size: 18,
                        color: c.muted,
                        onPressed: _query.clear,
                      ),
              ).applyDefaults(Theme.of(context).inputDecorationTheme),
            ),
          ),
          Gap.s14,
          if (items.isEmpty && (_isAll || searching))
            StateView(
              icon: Icons.search_off,
              title: 'No questions match',
              body: 'Try another word, or ask Atom.',
              actions: [
                AppButton.ghost('Clear search', onPressed: _query.clear),
              ],
            )
          else if (items.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TbdText(HelpContent.pendingAnswers),
                  Gap.s6,
                  Text(
                    'Answers for this topic are on their way. Ask Atom or '
                    'raise a complaint in the meantime.',
                    style: t.small,
                  ),
                ],
              ),
            )
          else
            // Canvas `.card` with no padding: 24 radius, hairline rows.
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.white,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.line),
                      _QuestionRow(
                        question: items[i].$2,
                        open: _open == items[i].$2.id,
                        onTap: () => setState(
                          () => _open = _open == items[i].$2.id
                              ? null
                              : items[i].$2.id,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Gap.s14,
          const AskAtomCard(
            title: 'Still stuck? Ask Atom',
            subtitle: 'It can see your limit and orders',
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const new({required this.question, required this.open, required this.onTap});

  final HelpQuestion question;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: open,
          child: Pressable(
            onTap: onTap,
            scaleOnPress: false,
            borderRadius: BorderRadius.zero,
            pressedColor: c.primarySoft,
            semanticLabel: question.question,
            excludeChildSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s16,
                  vertical: Space.s12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.question,
                        style: t.body.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.s12),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: context.reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: c.glyph,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              0,
              Space.s16,
              Space.s16,
            ),
            child: Text(
              question.answer,
              style: t.base.copyWith(fontWeight: FontWeight.w500, height: 1.55),
            ),
          ),
      ],
    );
  }
}

/// "Raise a complaint": the in-app grievance route.
class ComplaintScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

/// "Not about an order" in the order picker.
const _noOrder = 0;

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  String? _topic;
  int? _order;
  final _message = TextEditingController();
  final _focus = {
    'topic': FocusNode(),
    'order_id': FocusNode(),
    'message': FocusNode(),
  };

  bool get _dirty =>
      _topic != null || _order != null || _message.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final form = ref.read(complaintFormProvider.notifier);
    final reference = await form.send(
      topic: _topic,
      orderId: _order == _noOrder ? null : _order,
      message: _message.text,
    );
    if (!mounted) return;
    if (reference == null) {
      focusFirstError(ref.read(complaintFormProvider), _focus);
      return;
    }
    // Replaces the form, so back from "Complaint sent" goes to Help.
    context.pushReplacement(Routes.complaintSentWith(reference));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final status = ref.watch(complaintFormProvider);
    final offline = ref.watch(isOfflineProvider);
    final business = ref.watch(appConfigProvider).business;
    final topics =
        ref.watch(formOptionsProvider).value?.complaintTopics ??
        defaultComplaintTopics;
    final plans = ref.watch(plansProvider);

    return FormExitGuard(
      dirty: _dirty,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: const AppTopBar(title: 'Raise a complaint'),
        body: FormPage(
          children: [
            Text(
              'Tell us what went wrong. A person reads every complaint, '
              "and you'll get a reference number.",
              style: t.small,
            ),
            Gap.s16,
            // Canvas `.form{gap:14px}`.
            PickerField<String>(
              label: 'What is it about?',
              sheetTitle: 'What is it about?',
              searchPlaceholder: 'Search topics',
              noun: 'topics',
              focusNode: _focus['topic'],
              options: [for (final o in topics) PickerOption(o.value, o.label)],
              value: _topic,
              error: status.field('topic'),
              onChanged: (v) {
                setState(() => _topic = v);
                ref.read(complaintFormProvider.notifier).clearField('topic');
              },
            ),
            Gap.s14,
            PickerField<int>(
              label: 'Which order? (optional)',
              sheetTitle: 'Which order?',
              searchPlaceholder: 'Search by order number or product',
              noun: 'orders',
              focusNode: _focus['order_id'],
              loading: plans.isLoading && !plans.hasValue,
              options: [
                for (final p in plans.value?.data ?? const <Plan>[])
                  PickerOption(
                    p.order.id,
                    p.order.reference,
                    subtitle: _orderLine(p),
                  ),
                const PickerOption(
                  _noOrder,
                  'Not about an order',
                  subtitle: 'Leave this empty',
                ),
              ],
              value: _order,
              error: status.field('order_id'),
              onChanged: (v) => setState(() => _order = v),
            ),
            Gap.s14,
            AppTextField(
              label: 'What happened?',
              controller: _message,
              focusNode: _focus['message'],
              placeholder: 'Dates and amounts help us look into it faster.',
              minLines: 4,
              maxLines: 10,
              maxLength: maxComplaintLength,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              error: status.field('message'),
              hint:
                  'At least $minComplaintLength characters · '
                  '${_message.text.length} of $maxComplaintLength',
              onChanged: (_) => ref
                  .read(complaintFormProvider.notifier)
                  .clearField('message'),
            ),
            Gap.s16,
            SubmitSection(
              label: 'Send complaint',
              status: status,
              offline: offline,
              fieldsOnScreen: _focus.keys.toSet(),
              onSubmit: () => unawaited(_submit()),
            ),
            Gap.s16,
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s18,
                vertical: Space.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('What happens next', style: t.h4),
                  ),
                  Gap.s8,
                  TickList(
                    [
                      TextSpan(
                        children: [
                          const TextSpan(text: 'We reply within '),
                          factSpan(
                            context,
                            business.complaintResponseTime,
                            HelpPlaceholders.responseTime,
                          ),
                          const TextSpan(text: ', in the app and by email.'),
                        ],
                      ),
                      // Atomshop isn't SECP-licensed, so there's no SECP
                      // escalation to offer.
                      const TextSpan(
                        text:
                            'A person reads every complaint, and your '
                            'reference number tracks it.',
                      ),
                    ],
                    icons: const [Icons.check, Icons.shield_outlined],
                    color: c.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "OXY 3218L Android · delivered": the second line of an order.
  static String? _orderLine(Plan p) {
    final parts = [?p.product?.title, ?p.order.statusLabel?.toLowerCase()];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// "Complaint sent": the reference to quote, and where to go next.
class ComplaintSentScreen extends ConsumerWidget {
  const new({required this.reference, super.key});

  final String reference;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: reference));
    showToast('Reference copied');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    // Canvas: a white outcome screen with no bar; back still goes to Help.
    return Scaffold(
      backgroundColor: c.white,
      body: SafeArea(
        child: StateView(
          icon: Icons.check,
          iconTone: StateTone.green,
          title: 'Complaint sent',
          titleStyle: t.h2,
          actions: [
            AppButton.primary(
              'Back to Help',
              block: true,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.help);
                }
              },
            ),
            AppButton.ghost(
              'Go to Home',
              block: true,
              onPressed: () => context.go(Routes.home),
            ),
          ],
          child: Column(
            children: [
              Gap.s12,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text.rich(
                  TextSpan(
                    style: t.small,
                    children: [
                      const TextSpan(
                        text:
                            'A person will read it and reply in the app and '
                            'by email within ',
                      ),
                      factSpan(
                        context,
                        ref
                            .watch(appConfigProvider)
                            .business
                            .complaintResponseTime,
                        HelpPlaceholders.responseTime,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (reference.isNotEmpty) ...[
                Gap.s12,
                _RefBox(reference: reference, onCopy: () => unawaited(_copy())),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Canvas `.refbox`: dashed line-3 border, 16 radius, surface fill, the
/// reference at 17/800 and a small primary Copy button.
class _RefBox extends StatelessWidget {
  const new({required this.reference, required this.onCopy});

  final String reference;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return CustomPaint(
      foregroundPainter: _DashedBorder(c.line3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s14,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.row),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your reference', style: t.tiny),
                  // Copy is the button beside it; a selectable line here
                  // would be a long-press target under 48 dp.
                  Text(reference, style: t.h4.copyWith(letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(width: Space.s12),
            Pressable(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(Radii.pill),
              pressedColor: c.primarySoft,
              semanticLabel: 'Copy reference $reference',
              excludeChildSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: Sizes.target),
                padding: const EdgeInsets.symmetric(horizontal: Space.s14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: c.line2),
                ),
                child: Text(
                  'Copy',
                  style: t.small.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 1 px dashed rounded border (CSS `border:1px dashed`).
class _DashedBorder extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(Radii.row),
    ).deflate(0.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
