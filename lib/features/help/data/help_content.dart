import 'package:atompay_mobile/core/widgets/picker.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// One question and its answer.
@immutable
class HelpQuestion {
  const new(this.id, this.question, this.answer);

  /// Used in `?q=` to open a topic with this question expanded.
  final String id;
  final String question;
  final String answer;
}

/// A Help topic tile and its questions.
@immutable
class HelpTopic {
  const new({
    required this.key,
    required this.title,
    required this.icon,
    required this.tone,
    this.questions = const [],
  });

  /// The `:topic` in `/help/topic/:topic`.
  final String key;
  final String title;
  final IconData icon;
  final TileTone tone;

  /// Empty until the business supplies the answers: the topic then shows
  /// [HelpContent.pendingAnswers] rather than anything invented.
  final List<HelpQuestion> questions;
}

/// Help's questions and answers, word for word from the canvas ("Help
/// topic", "Ask Atom · answer"). They follow AtomPay's plan rules (brief
/// §2): 3 months, no advance, 0% markup. The website's FAQs still describe
/// a down payment and a chosen term, so they are not reused.
abstract final class HelpContent {
  /// The topic that lists every question, with search.
  static const all = 'all';

  /// Shown on a topic whose answers haven't been supplied.
  static const pendingAnswers = '[ANSWERS FOR THIS TOPIC]';

  static const _cost = HelpQuestion(
    'cost',
    'What does AtomPay cost?',
    'Nothing for the financing. AtomPay is 0% markup and takes no advance, '
        'so you repay exactly the cash price over 3 months. A 3% processing '
        'fee is shown with every plan as a disclaimer, and delivery charges '
        'apply.',
  );

  static const _buyDirect = HelpQuestion(
    'buy-directly',
    'Do I buy directly in AtomPay?',
    'No. You buy on Atomshop.pk and choose AtomPay at checkout. AtomPay is '
        'how you pay; it never sells anything itself.',
  );

  static const _eligible = HelpQuestion(
    'eligible',
    'Is every product on Atomshop eligible?',
    'No. Only products marked "AtomPay eligible" on their listing. The Shop '
        'tab shows the eligible ones that fit your limit.',
  );

  static const _monthly = HelpQuestion(
    'monthly-payment',
    'What decides my monthly payment?',
    'The cash price, split into three equal months. The last month takes '
        'any rounding. No advance and 0% markup. Each month has to fit '
        'inside your monthly cap.',
  );

  static const _afterOrder = HelpQuestion(
    'after-order',
    'What happens after I order?',
    'Atomshop handles the order and delivery as usual. Your three payments '
        'and their dates then appear under Orders.',
  );

  static const topics = [
    HelpTopic(
      key: 'getting-started',
      title: 'Getting started',
      icon: Icons.arrow_forward,
      tone: TileTone.blue,
    ),
    HelpTopic(
      key: 'limit',
      title: 'Your limit',
      icon: Icons.credit_card,
      tone: TileTone.wash,
      questions: [_monthly],
    ),
    HelpTopic(
      key: 'applying',
      title: 'Applying & KYC',
      icon: Icons.shield_outlined,
      tone: TileTone.green,
    ),
    HelpTopic(
      key: 'buying',
      title: 'Buying',
      icon: Icons.shopping_bag_outlined,
      tone: TileTone.blue,
      questions: [_buyDirect, _eligible, _monthly, _afterOrder],
    ),
    HelpTopic(
      key: 'payments',
      title: 'Payments',
      icon: Icons.schedule,
      tone: TileTone.amber,
      questions: [_cost],
    ),
    HelpTopic(
      key: 'account',
      title: 'Account',
      icon: Icons.person_outline,
      tone: TileTone.grey,
    ),
  ];

  /// Help's "Common questions", with the topic each opens.
  static const common = [
    ('payments', _cost),
    ('buying', _buyDirect),
    ('buying', _eligible),
    ('limit', _monthly),
  ];

  static HelpTopic? topic(String key) =>
      topics.where((t) => t.key == key).firstOrNull;

  /// Every question once, with the first topic it appears in.
  static List<(HelpTopic, HelpQuestion)> get everyQuestion {
    final seen = <String>{};
    return [
      for (final t in topics)
        for (final q in t.questions)
          if (seen.add(q.id)) (t, q),
    ];
  }

  /// Search ignores case and extra spaces and matches anywhere in the
  /// question or answer.
  static List<(HelpTopic, HelpQuestion)> search(String query) {
    final q = normaliseQuery(query);
    if (q.isEmpty) return everyQuestion;
    return [
      for (final item in everyQuestion)
        if ('${item.$2.question} ${item.$2.answer}'.toLowerCase().contains(q))
          item,
    ];
  }
}
