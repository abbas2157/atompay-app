import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:atompay_mobile/features/launch/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Future<Harness> _fresh(WidgetTester tester, {double textScale = 1}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final h = await Harness.create(consented: false, onboarded: false);
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  return h;
}

String _at(Harness h) => h.container.read(routerProvider).state.uri.path;

void main() {
  testWidgets('a new install starts on the intro slides', (tester) async {
    final h = await _fresh(tester);
    expect(_at(h), Routes.onboarding);
    expect(find.text(onboardingSlides.first.title), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Next walks the slides, Get started goes to First run', (
    tester,
  ) async {
    final h = await _fresh(tester);
    for (final slide in onboardingSlides.skip(1)) {
      await tester.tap(find.text('Next'));
      await settle(tester, frames: 10);
      expect(find.text(slide.title), findsOneWidget);
    }
    // The last slide: no Skip, the button finishes.
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    expect(_at(h), Routes.firstRun);
    expect(h.container.read(appPrefsProvider).onboarded, isTrue);
  });

  testWidgets('Skip goes straight to First run, once', (tester) async {
    final h = await _fresh(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(_at(h), Routes.firstRun);
    expect(h.prefs.getBool('onboarding.done_v1'), isTrue);
  });

  testWidgets('back steps to the previous slide', (tester) async {
    await _fresh(tester);
    await tester.tap(find.text('Next'));
    await settle(tester, frames: 10);
    await tester.binding.handlePopRoute();
    await settle(tester, frames: 10);
    expect(find.text(onboardingSlides.first.title), findsOneWidget);
  });

  testWidgets('an existing install that accepted the disclosures skips it', (
    tester,
  ) async {
    final h = await Harness.create(token: 'token');
    addTearDown(h.dispose);
    await h.prefs.remove('onboarding.done_v1');
    await h.pumpApp(tester);
    expect(_at(h), Routes.home);
  });

  testWidgets('targets, labels and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await _fresh(tester);
    for (var i = 0; i < onboardingSlides.length; i++) {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      if (i < onboardingSlides.length - 1) {
        await tester.tap(find.text('Next'));
        await settle(tester, frames: 10);
      }
    }
    handle.dispose();
  });

  testWidgets('text at 200% fits on every slide', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    await _fresh(tester, textScale: 2);
    for (var i = 0; i < onboardingSlides.length - 1; i++) {
      await tester.tap(find.text('Next'));
      await settle(tester, frames: 10);
    }
    FlutterError.onError = previous;
    expect(errors, isEmpty, reason: errors.join('\n\n'));
  });
}
