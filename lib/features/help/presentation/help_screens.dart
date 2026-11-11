import 'dart:async';

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

/// Placeholders the business hasn't supplied (brief §0).
abstract final class HelpPlaceholders {
  static const responseTime = '[RESPONSE TIME]';
  static const secpLink = '[SECP complaint link · verify]';
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
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(),
      body: FormPage(
        children: [
          Semantics(header: true, child: Text('How can we help?', style: t.h1)),
          Gap.s16,
          Pressable(
            onTap: () =>
                context.pushOnce(Routes.helpTopicSearch(HelpContent.all)),
            scaleOnPress: false,
            borderRadius: BorderRadius.circular(Radii.pill),
            semanticLabel: 'Search help',
            excludeChildSemantics: true,
            child: Container(
              height: Sizes.target,
              padding: const EdgeInsets.symmetric(horizontal: Space.s16),
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: c.line2),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: c.muted),
                  const SizedBox(width: Space.s10),
                  Expanded(
                    child: Text(
                      'Search: "limit", "late payment"…',
                      style: t.base.copyWith(color: c.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap.s16,
          const AskAtomCard(
            subtitle: 'Fastest: it knows your limit and your orders',
          ),
          Gap.s24,
          const SectionLabel('Topics'),
          GridView.count(
            crossAxisCount: width >= 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.s10,
            crossAxisSpacing: Space.s10,
            childAspectRatio: 2.4,
            children: [
              for (final topic in HelpContent.topics)
                _TopicTile(
                  topic: topic,
                  onTap: () => context.pushOnce(Routes.helpTopic(topic.key)),
                ),
            ],
          ),
          Gap.s24,
          ListGroup(
            title: 'Common questions',
            children: [
              for (final (key, q) in HelpContent.common)
                ListRow(
                  title: q.question,
                  summary: HelpContent.topic(key)!.title,
                  onTap: () => context.pushOnce(Routes.helpQuestion(key, q.id)),
                ),
              Pressable(
                onTap: () =>
                    context.pushOnce(Routes.helpTopic(HelpContent.all)),
                scaleOnPress: false,
                borderRadius: BorderRadius.zero,
                pressedColor: c.primarySoft,
                semanticLabel: 'All questions',
                excludeChildSemantics: true,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      'All questions',
                      style: t.base.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Gap.s24,
          ListGroup(
            title: 'Talk to us',
            children: [
              ListRow(
                title: 'Raise a complaint',
                summary: 'A person reads every one',
                icon: Icons.flag_outlined,
                tileTone: TileTone.rose,
                onTap: () => context.pushOnce(Routes.complaint),
              ),
              ..._contactRows(support),
            ],
          ),
          Gap.s16,
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: Space.s12),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(Radii.row),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            IconTile(topic.icon, tone: topic.tone, size: 36),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Text(
                topic.title,
                style: context.text.base.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
  const new({required this.subtitle, this.title = 'Ask Atom', super.key});

  final String title;
  final String subtitle;

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
          const AtomAvatar(),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(subtitle, style: t.small),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.glyph),
        ],
      ),
    );
  }
}

/// One topic with expandable answers; `all` lists every question with a
/// search box (canvas "Help topic").
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
    final topic = HelpContent.topic(widget.topic);
    final title = _isAll ? 'All questions' : (topic?.title ?? 'Help');
    final items = _isAll
        ? HelpContent.search(_query.text)
        : [for (final q in topic?.questions ?? <HelpQuestion>[]) (topic!, q)];

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppTopBar(title: title),
      body: FormPage(
        children: [
          if (_isAll) ...[
            AppTextField(
              label: 'Search questions',
              controller: _query,
              autofocus: widget.search,
              placeholder: 'Try "limit" or "payment"',
              textInputAction: TextInputAction.search,
              suffix: _query.text.isEmpty
                  ? const Icon(Icons.search)
                  : AppIconButton(
                      icon: Icons.close,
                      label: 'Clear search',
                      size: 20,
                      onPressed: _query.clear,
                    ),
            ),
            Gap.s16,
          ],
          if (items.isEmpty && _isAll)
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
            ListGroup(
              children: [
                for (final (_, q) in items)
                  _QuestionRow(
                    question: q,
                    open: _open == q.id,
                    onTap: () =>
                        setState(() => _open = _open == q.id ? null : q.id),
                  ),
              ],
            ),
          Gap.s16,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s16,
                vertical: Space.s14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      question.question,
                      style: t.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Space.s8),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: c.glyph,
                  ),
                ],
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
            child: Text(question.answer, style: t.base),
          ),
      ],
    );
  }
}

/// "Raise a complaint" (SECP Circular 15/2022 grievance route).
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
    final status = ref.watch(complaintFormProvider);
    final offline = ref.watch(isOfflineProvider);
    final topics =
        ref.watch(formOptionsProvider).value?.complaintTopics ??
        defaultComplaintTopics;
    final plans = ref.watch(plansProvider);

    return FormExitGuard(
      dirty: _dirty,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: const AppTopBar(title: 'Raise a complaint'),
        body: FormPage(
          footer: SubmitSection(
            label: 'Send complaint',
            status: status,
            offline: offline,
            fieldsOnScreen: _focus.keys.toSet(),
            onSubmit: () => unawaited(_submit()),
          ),
          children: [
            const PageIntro(
              title: 'Raise a complaint',
              lead:
                  'Tell us what went wrong. A person reads every complaint, '
                  "and you'll get a reference number.",
            ),
            Gap.s24,
            PickerField<String>(
              label: 'What is it about?',
              sheetTitle: 'Complaint topic',
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
            Gap.s16,
            PickerField<int>(
              label: 'Which order? (optional)',
              sheetTitle: 'Complaint order',
              noun: 'orders',
              focusNode: _focus['order_id'],
              loading: plans.isLoading && !plans.hasValue,
              options: [
                const PickerOption(_noOrder, 'Not about an order'),
                for (final p in plans.value?.data ?? const <Plan>[])
                  PickerOption(
                    p.order.id,
                    p.product == null
                        ? p.order.reference
                        : '${p.order.reference} · ${p.product!.title}',
                  ),
              ],
              value: _order,
              error: status.field('order_id'),
              onChanged: (v) => setState(() => _order = v),
            ),
            Gap.s16,
            AppTextField(
              label: 'What happened?',
              controller: _message,
              focusNode: _focus['message'],
              minLines: 5,
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
            Gap.s24,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What happens next', style: t.h4),
                  Gap.s8,
                  Text.rich(
                    TextSpan(
                      style: t.base,
                      children: [
                        const TextSpan(text: 'We reply within '),
                        placeholderSpan(context, HelpPlaceholders.responseTime),
                        const TextSpan(text: ', in the app and by email.'),
                      ],
                    ),
                  ),
                  Gap.s8,
                  Text.rich(
                    TextSpan(
                      style: t.base,
                      children: [
                        const TextSpan(
                          text:
                              'Not happy with our answer? You can take it '
                              'to the SECP: ',
                        ),
                        placeholderSpan(context, HelpPlaceholders.secpLink),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Complaint sent": the reference to quote, and where to go next.
class ComplaintSentScreen extends StatelessWidget {
  const new({required this.reference, super.key});

  final String reference;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: reference));
    showToast('Reference copied');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(),
      body: StateView(
        icon: Icons.check,
        iconTone: StateTone.green,
        title: 'Complaint sent',
        actions: [
          AppButton.primary(
            'Back to Help',
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
            onPressed: () => context.go(Routes.home),
          ),
        ],
        child: Column(
          children: [
            Gap.s8,
            Text.rich(
              TextSpan(
                style: t.small,
                children: [
                  const TextSpan(
                    text:
                        'A person will read it and reply in the app and by '
                        'email within ',
                  ),
                  placeholderSpan(context, HelpPlaceholders.responseTime),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (reference.isNotEmpty) ...[
              Gap.s16,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s16,
                  vertical: Space.s12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your reference', style: t.tiny),
                          SelectableText(reference, style: t.h3),
                        ],
                      ),
                    ),
                    AppButton.ghost(
                      'Copy',
                      icon: Icons.copy,
                      semanticLabel: 'Copy reference $reference',
                      onPressed: () => unawaited(_copy()),
                    ),
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
