import 'dart:async';

import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/ask_atom/application/ask_atom_controller.dart';
import 'package:atompay_mobile/features/ask_atom/data/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// A voice input the test drives.
class FakeVoice implements VoiceInput {
  MicPermission current = MicPermission.granted;
  MicPermission afterRequest = MicPermission.granted;
  int requests = 0;
  bool cancelled = false;
  late void Function(String text, {required bool done}) _onText;

  /// What the phone "hears".
  void hear(String text, {bool done = false}) => _onText(text, done: done);

  @override
  Future<MicPermission> status() async => current;

  @override
  Future<MicPermission> request() async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<bool> start({
    required void Function(String text, {required bool done}) onText,
    required VoidCallback onStopped,
  }) async {
    _onText = onText;
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async => cancelled = true;
}

class FakeSpeaker implements Speaker {
  final said = <String>[];
  Completer<void>? _reading;
  int stops = 0;

  @override
  Future<void> speak(String text) {
    said.add(text);
    _reading = Completer();
    return _reading!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (_reading?.isCompleted == false) _reading!.complete();
  }
}

String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

Future<Harness> at(
  WidgetTester tester,
  String route, {
  FakeVoice? voice,
  FakeSpeaker? speaker,
  FakeScenario scenario = FakeScenario.repaying,
}) async {
  tester.view
    ..physicalSize = const Size(420, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(
    scenario: scenario,
    token: 'token',
    overrides: [
      voiceInputProvider.overrideWithValue(voice ?? FakeVoice()),
      speakerProvider.overrideWithValue(speaker ?? FakeSpeaker()),
    ],
  );
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  h.container.read(routerProvider).go(route);
  await settle(tester);
  return h;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final f = find.bySemanticsLabel(label).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void main() {
  group('Ask Atom', () {
    testWidgets('start screen: Atom noticed and suggested questions', (
      tester,
    ) async {
      await at(tester, Routes.atom);
      expect(find.text('Answers about AtomPay in seconds'), findsOneWidget);
      expect(find.text('ATOM NOTICED'), findsOneWidget);
      expect(find.textContaining('is due'), findsOneWidget);
      expect(find.text('See the schedule'), findsOneWidget);
      expect(find.text('What does AtomPay cost?'), findsOneWidget);
      expect(find.text('When are my payments due?'), findsOneWidget);
    });

    testWidgets('a chip asks it; bold, table and action render', (
      tester,
    ) async {
      final h = await at(tester, Routes.atom);
      await tapText(tester, 'What does AtomPay cost?');

      expect(
        find.bySemanticsLabel('You asked: What does AtomPay cost?'),
        findsOneWidget,
      );
      // **bold** becomes a bold span, never literal asterisks.
      expect(find.textContaining('**'), findsNothing);
      expect(
        find.textContaining('3 months, no advance and 0% markup'),
        findsOneWidget,
      );
      expect(find.text('Rs. 15,666'), findsNWidgets(2));
      expect(find.text('Rs. 15,668'), findsOneWidget);

      await tapText(tester, 'Try the calculator');
      expect(location(h), Routes.calculator);
    });

    testWidgets('a typed question is sent; follow-up chips appear', (
      tester,
    ) async {
      await at(tester, Routes.atom);
      await tester.enterText(find.byType(TextField), '  how is my LIMIT  ');
      await settle(tester);
      await tapLabel(tester, 'Send');
      expect(find.textContaining('30% of your monthly income'), findsOneWidget);
      expect(find.text('See eligible products'), findsOneWidget);
      // The follow-ups leave out the question just answered.
      expect(find.text('How is my limit worked out?'), findsNothing);
      expect(find.text('What does AtomPay cost?'), findsOneWidget);
    });

    testWidgets('Listen reads one answer aloud and toggles to Stop', (
      tester,
    ) async {
      final speaker = FakeSpeaker();
      await at(tester, Routes.atom, speaker: speaker);
      await tapText(tester, 'What does AtomPay cost?');

      await tapLabel(tester, 'Read this answer aloud');
      expect(speaker.said.single, contains('3 months, no advance'));
      expect(speaker.said.single, contains('Month 3, Rupees 15,668.'));
      expect(speaker.said.single, isNot(contains('**')));
      expect(find.text('Stop'), findsOneWidget);

      await tapLabel(tester, 'Stop reading aloud');
      expect(speaker.stops, greaterThan(0));
      expect(find.text('Listen'), findsOneWidget);
    });

    testWidgets('voice, granted: listens, shows the transcript, Done sends', (
      tester,
    ) async {
      final voice = FakeVoice();
      await at(tester, Routes.atom, voice: voice);
      await tapLabel(tester, 'Ask by voice');

      expect(
        find.text('Speak in English. Stops by itself when you pause.'),
        findsOneWidget,
      );
      voice.hear('When are my payments');
      await settle(tester);
      expect(find.text('When are my payments'), findsOneWidget);

      await tapText(tester, 'Done');
      expect(
        find.text('Speak in English. Stops by itself when you pause.'),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('You asked: When are my payments'),
        findsOneWidget,
      );
      expect(find.textContaining('Your next payment is'), findsOneWidget);
    });

    testWidgets('voice: a pause ends listening and sends the text', (
      tester,
    ) async {
      final voice = FakeVoice();
      await at(tester, Routes.atom, voice: voice);
      await tapLabel(tester, 'Ask by voice');
      voice.hear('what does it cost', done: true);
      await settle(tester);
      expect(find.textContaining('0% markup'), findsOneWidget);
    });

    testWidgets('voice: nothing heard says so and sends nothing', (
      tester,
    ) async {
      final voice = FakeVoice();
      final h = await at(tester, Routes.atom, voice: voice);
      await tapLabel(tester, 'Ask by voice');
      voice.hear('', done: true);
      await settle(tester);
      expect(
        find.text("I didn't catch that. Try again, or type your question."),
        findsOneWidget,
      );
      expect(h.server.log.where((r) => r.path.endsWith('/ask-atom')), isEmpty);
    });

    testWidgets('voice: Cancel sends nothing', (tester) async {
      final voice = FakeVoice();
      await at(tester, Routes.atom, voice: voice);
      await tapLabel(tester, 'Ask by voice');
      voice.hear('what does it cost');
      await settle(tester);
      await tapText(tester, 'Cancel');
      expect(voice.cancelled, isTrue);
      expect(find.text('ATOM NOTICED'), findsOneWidget);
    });

    testWidgets('voice, first tap: the explainer comes before the prompt', (
      tester,
    ) async {
      final voice = FakeVoice()..current = MicPermission.notAsked;
      await at(tester, Routes.atom, voice: voice);

      await tapLabel(tester, 'Ask by voice');
      expect(find.text('Ask Atom with your voice'), findsOneWidget);
      expect(voice.requests, 0);
      await tapText(tester, "Not now, I'll type");
      expect(voice.requests, 0);

      await tapLabel(tester, 'Ask by voice');
      await tapText(tester, 'Allow microphone');
      expect(voice.requests, 1);
      expect(
        find.text('Speak in English. Stops by itself when you pause.'),
        findsOneWidget,
      );
      await tapText(tester, 'Cancel');
    });

    testWidgets('voice, denied: stays put, then the mic opens Permissions', (
      tester,
    ) async {
      final voice = FakeVoice()
        ..current = MicPermission.notAsked
        ..afterRequest = MicPermission.denied;
      final h = await at(tester, Routes.atom, voice: voice);

      await tapLabel(tester, 'Ask by voice');
      await tapText(tester, 'Allow microphone');
      expect(location(h), Routes.atom);
      expect(
        find.text('Speak in English. Stops by itself when you pause.'),
        findsNothing,
      );

      await tapLabel(tester, 'Ask by voice');
      expect(location(h), Routes.permissions);
    });

    testWidgets('voice, permanently denied: the mic opens Permissions', (
      tester,
    ) async {
      final voice = FakeVoice()..current = MicPermission.blocked;
      final h = await at(tester, Routes.atom, voice: voice);
      await tapLabel(tester, 'Ask by voice');
      expect(voice.requests, 0);
      expect(location(h), Routes.permissions);
    });

    test('bold spans', () {
      expect(boldSpans('a **b** c'), [
        ('a ', false),
        ('b', true),
        (' c', false),
      ]);
      expect(boldSpans('plain'), [('plain', false)]);
      expect(boldSpans('**x**'), [('x', true)]);
    });
  });

  group('Help', () {
    testWidgets('topics, common questions; null contacts are hidden', (
      tester,
    ) async {
      final h = await at(tester, Routes.help);
      expect(find.text('How can we help?'), findsOneWidget);
      expect(find.text('Raise a complaint'), findsOneWidget);
      // The fake's support values are null: no invented numbers.
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Call'), findsNothing);
      expect(find.text('Email'), findsNothing);

      await tapLabel(tester, 'Buying');
      expect(location(h), Routes.helpTopic('buying'));
      expect(
        find.text('Is every product on Atomshop eligible?'),
        findsOneWidget,
      );
      expect(find.textContaining('AtomPay eligible'), findsNothing);
      await tapText(tester, 'Is every product on Atomshop eligible?');
      expect(find.textContaining('"AtomPay eligible"'), findsOneWidget);
    });

    testWidgets('a common question opens its topic, expanded', (tester) async {
      final h = await at(tester, Routes.help);
      await tapText(tester, 'What does AtomPay cost?');
      expect(location(h), Routes.helpQuestion('payments', 'cost'));
      expect(find.textContaining('Nothing for the financing'), findsOneWidget);
    });

    testWidgets('a topic without answers shows the placeholder', (
      tester,
    ) async {
      await at(tester, Routes.helpTopic('account'));
      expect(find.text('[ANSWERS FOR THIS TOPIC]'), findsOneWidget);
      expect(find.text('Still stuck? Ask Atom'), findsOneWidget);
    });

    testWidgets('All questions searches; empty state clears', (tester) async {
      await at(tester, Routes.helpTopic('all'));
      expect(find.text('What happens after I order?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  ROUNDING ');
      await settle(tester);
      expect(find.text('What decides my monthly payment?'), findsOneWidget);
      expect(find.text('What happens after I order?'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);
      expect(find.text('No questions match'), findsOneWidget);
      await tapText(tester, 'Clear search');
      expect(find.text('What happens after I order?'), findsOneWidget);
    });

    testWidgets('an unknown topic goes back to Help', (tester) async {
      final h = await at(tester, Routes.helpTopic('nope'));
      expect(location(h), Routes.help);
    });
  });

  group('Complaints', () {
    testWidgets('validates, sends, and lands on Complaint sent', (
      tester,
    ) async {
      final h = await at(tester, Routes.help);
      await tapText(tester, 'Raise a complaint');
      expect(location(h), Routes.complaint);
      expect(find.text('[RESPONSE TIME]'), findsNothing); // inside rich text
      expect(find.textContaining('[RESPONSE TIME]'), findsOneWidget);
      expect(find.textContaining('[SECP complaint link'), findsOneWidget);

      await tapText(tester, 'Send complaint');
      expect(find.text('Choose what it is about.'), findsOneWidget);
      expect(
        find.text('Tell us a little more: at least 10 characters.'),
        findsOneWidget,
      );
      expect(h.server.complaints, isEmpty);

      await tapLabel(tester, 'What is it about?, not chosen');
      // The sheet's title repeats the field label.
      expect(find.text('What is it about?'), findsNWidgets(2));
      await tapText(tester, 'A payment');
      await tapText(tester, 'Use A payment');
      await tapLabel(tester, 'Which order? (optional), not chosen');
      await tapText(tester, 'Not about an order');
      await tapText(tester, 'Use Not about an order');
      await tester.enterText(
        find.byType(TextField),
        'My payment was taken twice this month.',
      );
      await settle(tester);
      await tapText(tester, 'Send complaint');

      expect(h.server.complaints.single['topic'], 'payment');
      expect(h.server.complaints.single['order_id'], isNull);
      expect(find.text('Complaint sent'), findsOneWidget);
      final ref = h.server.complaints.single['reference'] as String;
      expect(find.text(ref), findsOneWidget);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await tapLabel(tester, 'Copy reference $ref');
      expect(copied, ref);

      // The form was replaced: back goes to Help.
      await tapText(tester, 'Back to Help');
      expect(location(h), Routes.help);
    });

    testWidgets('a dirty form asks before discarding', (tester) async {
      final h = await at(tester, Routes.help);
      await tapText(tester, 'Raise a complaint');
      await tester.enterText(find.byType(TextField), 'Something');
      await settle(tester);
      await tapLabel(tester, 'Back');
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tapText(tester, 'Keep editing');
      expect(location(h), Routes.complaint);
      await tapLabel(tester, 'Back');
      await tapText(tester, 'Discard');
      expect(location(h), Routes.help);
    });
  });
}
