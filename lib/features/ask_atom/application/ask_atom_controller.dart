import 'package:atompay_mobile/features/ask_atom/data/ask_atom_repository.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suggested questions on the start screen.
final atomChipsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(askAtomRepositoryProvider).chips();
});

/// One question and its answer (loading, failed or in).
@immutable
class AtomTurn {
  const new({required this.id, required this.question, required this.answer});

  final int id;
  final String question;
  final AsyncValue<AtomAnswer> answer;

  AtomTurn withAnswer(AsyncValue<AtomAnswer> a) =>
      AtomTurn(id: id, question: question, answer: a);
}

/// The conversation. It lasts for the session, so closing Ask Atom and
/// opening it again keeps it; signing out clears it.
final askAtomProvider = NotifierProvider<AskAtomController, List<AtomTurn>>(
  AskAtomController.new,
);

class AskAtomController extends Notifier<List<AtomTurn>> {
  int _nextId = 0;

  @override
  List<AtomTurn> build() {
    ref.watch(sessionUserIdProvider);
    return const [];
  }

  /// Whether an answer is on its way: one question at a time.
  bool get busy => state.any((t) => t.answer.isLoading);

  /// Sends [question] unless it is empty or another one is in flight.
  Future<void> ask(String question) async {
    final q = question.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty || busy) return;
    final text = q.length > maxQuestionLength
        ? q.substring(0, maxQuestionLength)
        : q;
    final turn = AtomTurn(
      id: _nextId++,
      question: text,
      answer: const AsyncLoading(),
    );
    state = [...state, turn];
    await _answer(turn);
  }

  /// Asks a failed question again.
  Future<void> retry(int id) async {
    if (busy) return;
    final turn = state.where((t) => t.id == id).firstOrNull;
    if (turn == null) return;
    _replace(turn.withAnswer(const AsyncLoading()));
    await _answer(turn);
  }

  Future<void> _answer(AtomTurn turn) async {
    final result = await AsyncValue.guard(
      () => ref.read(askAtomRepositoryProvider).ask(turn.question),
    );
    if (!ref.mounted) return;
    _replace(turn.withAnswer(result));
  }

  void _replace(AtomTurn turn) =>
      state = state.map((t) => t.id == turn.id ? turn : t).toList();
}

/// `**bold**` spans in an answer, as (text, bold) pieces. Nothing else is
/// markup (brief §7.2).
List<(String, bool)> boldSpans(String paragraph) {
  final out = <(String, bool)>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var at = 0;
  for (final m in pattern.allMatches(paragraph)) {
    if (m.start > at) out.add((paragraph.substring(at, m.start), false));
    out.add((m.group(1)!, true));
    at = m.end;
  }
  if (at < paragraph.length) out.add((paragraph.substring(at), false));
  return out;
}

/// What "Listen" reads: the paragraphs without markup, then the table.
String spokenAnswer(AtomAnswer a, String Function(int) money) => [
  for (final p in a.paragraphs) p.replaceAll('**', ''),
  for (final row in a.table ?? const <AtomRow>[])
    '${row.label}, ${money(row.value)}.',
].join(' ');
