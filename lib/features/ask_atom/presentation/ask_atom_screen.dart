import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/ask_atom/application/ask_atom_controller.dart';
import 'package:atompay_mobile/features/ask_atom/data/ask_atom_repository.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/home/data/dashboard_models.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ask Atom (canvas boards "Ask Atom", "· answer", "· listening",
/// "· microphone permission"). Full screen over the current tab; Close,
/// back and the swipe return to it. Answers are rules-based, from
/// `POST /ask-atom`.
class AskAtomScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AskAtomScreen> createState() => _AskAtomScreenState();
}

class _AskAtomScreenState extends ConsumerState<AskAtomScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  // Voice.
  bool _listening = false;
  String _heard = '';
  int _seconds = 0;
  Timer? _clock;

  // Read aloud: one answer at a time.
  int? _speakingId;

  // Kept from initState: `ref` can't be used in dispose().
  late final VoiceInput _voice;
  late final Speaker _speaker;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _voice = ref.read(voiceInputProvider);
    _speaker = ref.read(speakerProvider);
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_listening) unawaited(_voice.cancel());
    if (_speakingId != null) unawaited(_speaker.stop());
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- asking ---------------------------------------------------------------

  Future<void> _send(String question) async {
    final q = question.trim();
    if (q.isEmpty || ref.read(askAtomProvider.notifier).busy) return;
    _input.clear();
    _toBottom();
    await ref.read(askAtomProvider.notifier).ask(q);
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (context.reduceMotion) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(
        end,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  /// Action routes are app paths (brief §7.2): Ask Atom closes and the
  /// route opens in its tab.
  void _open(String route) {
    if (!route.startsWith('/')) return;
    context.go(route);
  }

  // ---- voice ----------------------------------------------------------------

  Future<void> _micTap() async {
    if (_listening) return;
    final voice = _voice;
    var status = await voice.status();
    if (!mounted) return;
    if (status == MicPermission.notAsked) {
      final allow = await _explainMic();
      if (!allow || !mounted) return;
      status = await voice.request();
      if (!mounted) return;
      // Refused at the prompt: stay here; the next tap opens Permissions.
      if (status != MicPermission.granted) return;
    }
    switch (status) {
      case MicPermission.granted:
        await _listen();
      case MicPermission.denied || MicPermission.blocked:
        context.go(Routes.permissions);
      case MicPermission.notAsked:
        break;
    }
  }

  /// "Ask Atom with your voice": why, before the system prompt.
  Future<bool> _explainMic() async {
    final allow = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final t = context.text;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s20,
              0,
              Space.s20,
              Space.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: IconTile(Icons.mic_none, size: 56),
                ),
                Gap.s16,
                Semantics(
                  header: true,
                  child: Text('Ask Atom with your voice', style: t.h3),
                ),
                Gap.s8,
                Text(
                  'AtomPay uses the microphone only while you hold this '
                  'conversation open and tap the mic. Your phone turns '
                  'speech into text; we keep the text, never the recording.',
                  style: t.base,
                ),
                Gap.s20,
                AppButton.primary(
                  'Allow microphone',
                  large: true,
                  block: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                Gap.s8,
                AppButton.ghost(
                  "Not now, I'll type",
                  block: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
    return allow ?? false;
  }

  Future<void> _listen() async {
    unawaited(_stopSpeaking());
    setState(() {
      _listening = true;
      _heard = '';
      _seconds = 0;
    });
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    final ok = await _voice.start(
      onText: (text, {required done}) {
        if (!mounted || !_listening) return;
        setState(() => _heard = text);
        if (done) _finishVoice(send: true);
      },
      onStopped: () {
        if (mounted && _listening) _finishVoice(send: true);
      },
    );
    if (!ok && mounted) {
      _finishVoice(send: false);
      showToast("Voice isn't available on this phone. Type instead.");
    }
  }

  /// Done, or a pause: only the text is sent.
  void _finishVoice({required bool send}) {
    if (!_listening) return;
    _clock?.cancel();
    final heard = _heard;
    setState(() => _listening = false);
    if (!send) return;
    if (heard.trim().isEmpty) {
      // A pause with nothing heard: say so rather than just closing.
      showToast("I didn't catch that. Try again, or type your question.");
      return;
    }
    unawaited(_send(heard));
  }

  void _done() {
    unawaited(_voice.stop());
    _finishVoice(send: true);
  }

  void _cancel() {
    unawaited(_voice.cancel());
    _finishVoice(send: false);
  }

  // ---- read aloud -----------------------------------------------------------

  Future<void> _toggleSpeak(AtomTurn turn, AtomAnswer answer) async {
    final speaker = _speaker;
    if (_speakingId == turn.id) {
      await _stopSpeaking();
      return;
    }
    if (_speakingId != null) await speaker.stop();
    setState(() => _speakingId = turn.id);
    try {
      await speaker.speak(spokenAnswer(answer, rsSpoken));
    } on Object {
      showToast("Couldn't read this aloud.", error: true);
    }
    if (mounted && _speakingId == turn.id) setState(() => _speakingId = null);
  }

  Future<void> _stopSpeaking() async {
    if (_speakingId == null) return;
    setState(() => _speakingId = null);
    await _speaker.stop();
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final turns = ref.watch(askAtomProvider);
    final busy = turns.any((t) => t.answer.isLoading);
    final voiceOn = ref.watch(appConfigProvider).features.voice;
    final c = context.colors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark screen: light status-bar icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.surface,
        body: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(Space.gutter),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (turns.isEmpty)
                    _Start(onAsk: _send, onOpen: _open)
                  else
                    for (var i = 0; i < turns.length; i++)
                      _Turn(
                        turn: turns[i],
                        last: i == turns.length - 1,
                        speaking: _speakingId == turns[i].id,
                        onSpeak: _toggleSpeak,
                        onAsk: _send,
                        onOpen: _open,
                        onRetry: () => unawaited(
                          ref.read(askAtomProvider.notifier).retry(turns[i].id),
                        ),
                      ),
                ],
              ),
            ),
            if (_listening)
              _ListeningPanel(
                heard: _heard,
                seconds: _seconds,
                onCancel: _cancel,
                onDone: _done,
              )
            else
              _InputBar(
                controller: _input,
                focusNode: _inputFocus,
                busy: busy,
                showMic: voiceOn,
                onMic: () => unawaited(_micTap()),
                onSend: () => unawaited(_send(_input.text)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ink header: Close, Atom, and "Talk to a person" (Help).
class _Header extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Material(
      color: c.ink,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s8,
              vertical: Space.s6,
            ),
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.close,
                  label: 'Close Ask Atom',
                  color: c.white,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: Space.s4),
                const AtomAvatar(size: 42),
                const SizedBox(width: Space.s10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Atom', style: t.h4.copyWith(color: c.white)),
                        Text(
                          'Answers about AtomPay in seconds',
                          style: t.tiny.copyWith(color: c.onDark2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Icons.support_agent,
                  label: 'Talk to a person',
                  color: c.white,
                  onPressed: () => context.go(Routes.help),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The start screen: greeting, "Atom noticed" cards, suggested questions.
class _Start extends ConsumerWidget {
  const new({required this.onAsk, required this.onOpen});

  final ValueChanged<String> onAsk;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final first = ref.watch(currentUserProvider)?.firstName;
    final dashboard = ref.watch(dashboardProvider).value?.data;
    final chips = ref.watch(atomChipsProvider);
    final noticed = dashboard == null ? const <Widget>[] : _noticed(dashboard);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            first == null || first.isEmpty
                ? 'What would you like to know?'
                : 'Hi $first. What would you like to know?',
            style: t.h2,
          ),
        ),
        Gap.s16,
        if (noticed.isNotEmpty) ...[
          const SectionLabel('Atom noticed'),
          for (final card in noticed) ...[card, Gap.s12],
          Gap.s4,
        ],
        const SectionLabel('Ask'),
        switch (chips) {
          AsyncData(:final value) => _Chips(value, onTap: onAsk),
          AsyncError() => Text('Type a question below.', style: t.small),
          _ => const LoadingShape(
            label: 'Loading suggested questions',
            child: Wrap(
              spacing: Space.s8,
              runSpacing: Space.s8,
              children: [
                Skeleton(width: 180, height: 44),
                Skeleton(width: 150, height: 44),
                Skeleton(width: 200, height: 44),
              ],
            ),
          ),
        },
      ],
    );
  }

  /// Facts from `/dashboard`, shown as they are: nothing is worked out.
  List<Widget> _noticed(Dashboard d) => [
    if (d.nextDue case final due?)
      _NoticeCard(
        icon: Icons.event_outlined,
        tone: TileTone.amber,
        title:
            'Your ${due.label.toLowerCase()} is due '
            '${dayMonth(due.dueDate)}',
        body: [
          rs(due.amount),
          if (due.productTitle != null) 'for ${due.productTitle}',
        ].join(' '),
        spokenBody: [
          rsSpoken(due.amount),
          if (due.productTitle != null) 'for ${due.productTitle}',
        ].join(' '),
        action: 'See the schedule',
        onAction: () => onOpen(Routes.plan(due.orderId)),
      ),
    if (d.limit.hasLimit)
      _NoticeCard(
        icon: Icons.account_balance_wallet_outlined,
        tone: TileTone.wash,
        title: '${rs(d.limit.available)} left to spend',
        spokenTitle: '${rsSpoken(d.limit.available)} left to spend',
      ),
  ];
}

class _NoticeCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.tone,
    required this.title,
    this.spokenTitle,
    this.body,
    this.spokenBody,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final TileTone tone;
  final String title;
  final String? spokenTitle;
  final String? body;
  final String? spokenBody;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(Radii.row),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, tone: tone),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: spokenTitle,
                  excludeSemantics: spokenTitle != null,
                  child: Text(
                    title,
                    style: t.base.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (body != null)
                  Semantics(
                    label: spokenBody,
                    excludeSemantics: spokenBody != null,
                    child: Text(body!, style: t.small),
                  ),
                if (action != null) ...[
                  Gap.s8,
                  AppButton.primary(action!, onPressed: onAction),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested questions as pills.
class _Chips extends StatelessWidget {
  const new(this.chips, {required this.onTap});

  final List<String> chips;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final chip in chips)
          Pressable(
            onTap: () => onTap(chip),
            semanticLabel: 'Ask: $chip',
            excludeChildSemantics: true,
            pressedColor: c.primarySoft,
            child: Container(
              constraints: const BoxConstraints(minHeight: Sizes.target),
              padding: const EdgeInsets.symmetric(horizontal: Space.s16),
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: c.line2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      chip,
                      style: t.small.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w700,
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
}

/// A question and Atom's answer to it.
class _Turn extends StatelessWidget {
  const new({
    required this.turn,
    required this.last,
    required this.speaking,
    required this.onSpeak,
    required this.onAsk,
    required this.onOpen,
    required this.onRetry,
  });

  final AtomTurn turn;
  final bool last;
  final bool speaking;
  final Future<void> Function(AtomTurn, AtomAnswer) onSpeak;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final answer = turn.answer;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The question.
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.8,
              alignment: Alignment.centerRight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s14,
                    vertical: Space.s10,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(Radii.row),
                      topRight: Radius.circular(Radii.row),
                      bottomLeft: Radius.circular(Radii.row),
                      bottomRight: Radius.circular(Space.s4),
                    ),
                  ),
                  child: Semantics(
                    container: true,
                    label: 'You asked: ${turn.question}',
                    excludeSemantics: true,
                    child: Text(
                      turn.question,
                      style: t.base.copyWith(color: c.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Gap.s12,
          _BotBubble(
            child: switch (answer) {
              AsyncData(:final value) => _AnswerBody(
                answer: value,
                speaking: speaking,
                onSpeak: () => onSpeak(turn, value),
                onOpen: onOpen,
              ),
              AsyncError(:final error) => _AnswerError(
                error: error,
                onRetry: onRetry,
              ),
              _ => const LoadingShape(
                label: 'Atom is answering',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 200),
                    SizedBox(height: Space.s8),
                    Skeleton(width: 140),
                  ],
                ),
              ),
            },
          ),
          if (last && answer.value?.chips.isNotEmpty == true) ...[
            Gap.s12,
            _Chips(answer.value!.chips, onTap: onAsk),
          ],
        ],
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const AtomAvatar(size: 30),
        const SizedBox(width: Space.s8),
        Flexible(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s14,
              vertical: Space.s12,
            ),
            decoration: BoxDecoration(
              color: c.white,
              border: Border.all(color: c.line),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Radii.row),
                topRight: Radius.circular(Radii.row),
                bottomLeft: Radius.circular(Space.s4),
                bottomRight: Radius.circular(Radii.row),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _AnswerBody extends StatefulWidget {
  const new({
    required this.answer,
    required this.speaking,
    required this.onSpeak,
    required this.onOpen,
  });

  final AtomAnswer answer;
  final bool speaking;
  final VoidCallback onSpeak;
  final ValueChanged<String> onOpen;

  @override
  State<_AnswerBody> createState() => _AnswerBodyState();
}

class _AnswerBodyState extends State<_AnswerBody> {
  /// Thumbs up (true) or down (false). Kept on the phone: there is no
  /// feedback endpoint.
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final a = widget.answer;
    final style = t.base.copyWith(height: 1.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in a.paragraphs) ...[
          Text.rich(
            TextSpan(
              style: style,
              children: [
                for (final (text, bold) in boldSpans(p))
                  TextSpan(
                    text: text,
                    style: bold
                        ? TextStyle(color: c.ink, fontWeight: FontWeight.w800)
                        : null,
                  ),
              ],
            ),
          ),
          Gap.s10,
        ],
        if (a.table case final rows? when rows.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.line),
                  Semantics(
                    label: '${rows[i].label}, ${rsSpoken(rows[i].value)}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s12,
                        vertical: Space.s8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rows[i].label,
                              style: t.small.copyWith(color: c.body),
                            ),
                          ),
                          Text(
                            rs(rows[i].value),
                            style: t.small.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Gap.s10,
        ],
        for (final action in a.actions) ...[
          AppButton.ghost(
            action.label,
            onPressed: () => widget.onOpen(action.route),
          ),
          Gap.s10,
        ],
        Row(
          children: [
            _SmallButton(
              icon: widget.speaking ? Icons.stop : Icons.volume_up_outlined,
              text: widget.speaking ? 'Stop' : 'Listen',
              label: widget.speaking
                  ? 'Stop reading aloud'
                  : 'Read this answer aloud',
              selected: widget.speaking,
              onTap: widget.onSpeak,
            ),
            const Spacer(),
            ExcludeSemantics(child: Text('Helpful?', style: t.tiny)),
            _SmallButton(
              icon: Icons.thumb_up_outlined,
              label: 'Helpful',
              selected: _helpful ?? false,
              onTap: () => setState(() => _helpful = true),
            ),
            _SmallButton(
              icon: Icons.thumb_down_outlined,
              label: 'Not helpful',
              selected: _helpful == false,
              onTap: () => setState(() => _helpful = false),
            ),
          ],
        ),
      ],
    );
  }
}

/// A 32 dp bordered control with a 48 dp hit area.
class _SmallButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.text,
  });

  final IconData icon;
  final String label;
  final String? text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.primary : c.body;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      scaleOnPress: false,
      child: HitArea(
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 32),
          padding: EdgeInsets.symmetric(
            horizontal: text == null ? 0 : Space.s10,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.white,
            borderRadius: BorderRadius.circular(Space.s10),
            border: Border.all(color: selected ? c.primaryLine : c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              if (text != null) ...[
                const SizedBox(width: Space.s6),
                Text(
                  text!,
                  style: context.text.tiny.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerError extends StatelessWidget {
  const new({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      Offline() => "You're offline. Check your connection and try again.",
      Timeout() => 'This is taking too long. Please try again.',
      RateLimited() => 'Too many questions at once. Try again in a minute.',
      final Validation v => v.message,
      final Server s =>
        'Something went wrong on our side'
            '${s.reference == null ? '' : ' (reference ${s.reference})'}.',
      _ => "Atom couldn't answer that. Please try again.",
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: context.text.base.copyWith(color: context.colors.rose),
          ),
        ),
        if (error is! Validation) TextLink('Try again', onPressed: onRetry),
      ],
    );
  }
}

/// Text box, mic and Send.
class _InputBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.showMic,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool showMic;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final canSend = !busy && controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: c.white,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.s12,
        Space.s10,
        Space.s12,
        Space.s10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: t.body,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxQuestionLength),
                ],
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
                decoration: InputDecoration(
                  hintText: 'Ask about your limit, a plan, a payment',
                  semanticCounterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    borderSide: BorderSide(color: c.line2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    borderSide: BorderSide(color: c.primary, width: 2),
                  ),
                ).applyDefaults(Theme.of(context).inputDecorationTheme),
              ),
            ),
            if (showMic) ...[
              const SizedBox(width: Space.s8),
              AppIconButton(
                icon: Icons.mic_none,
                label: 'Ask by voice',
                color: c.primary,
                background: c.primarySoft,
                onPressed: busy ? null : onMic,
              ),
            ],
            const SizedBox(width: Space.s8),
            AppIconButton(
              icon: Icons.arrow_forward,
              label: 'Send',
              color: c.white,
              background: canSend ? c.primary : c.line,
              onPressed: canSend ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Listening · 0:04": waveform, live transcript, Cancel and Done.
class _ListeningPanel extends StatelessWidget {
  const new({
    required this.heard,
    required this.seconds,
    required this.onCancel,
    required this.onDone,
  });

  final String heard;
  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final time = '$seconds'.padLeft(2, '0');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.white,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.all(Space.s16),
      child: SafeArea(
        top: false,
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LISTENING · 0:$time',
                style: t.eyebrow,
                semanticsLabel: 'Listening',
              ),
              Gap.s12,
              const ExcludeSemantics(child: _Waveform()),
              Gap.s12,
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.target),
                child: Text(
                  heard.isEmpty ? '…' : heard,
                  style: t.h4,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                'Speak in English. Stops by itself when you pause.',
                style: t.tiny,
                textAlign: TextAlign.center,
              ),
              Gap.s16,
              Row(
                children: [
                  Expanded(
                    child: AppButton.ghost(
                      'Cancel',
                      block: true,
                      onPressed: onCancel,
                    ),
                  ),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: AppButton.primary(
                      'Done',
                      block: true,
                      onPressed: onDone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Twelve bars. Still under reduced motion.
class _Waveform extends StatefulWidget {
  const new();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  static const _heights = <double>[
    14,
    26,
    38,
    22,
    34,
    18,
    30,
    40,
    24,
    16,
    28,
    12,
  ];
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _heights.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                child: Container(
                  width: 5,
                  height: context.reduceMotion
                      ? _heights[i]
                      : _heights[i] *
                            (0.35 + 0.65 * ((_anim.value + i * 0.15) % 1)),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
