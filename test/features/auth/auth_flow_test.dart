import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

/// The top route, pushed ones included (`currentConfiguration.uri` only
/// gives the base location).
String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

void main() {
  testWidgets('first run is shown once, before sign-in', (tester) async {
    final h = await Harness.create(consented: false);
    addTearDown(h.dispose);
    await h.pumpApp(tester);

    expect(location(h), startsWith(Routes.firstRun));
    expect(find.text('[LICENSED ENTITY NAME]'), findsOneWidget);

    // Continue stays disabled until the declaration is ticked.
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(location(h), startsWith(Routes.firstRun));

    await tester.ensureVisible(find.text('I have read the privacy policy.'));
    await tester.tap(find.text('I have read the privacy policy.'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(location(h), Routes.welcome);
    expect(h.prefs.getBool('consent.accepted_v1'), isTrue);
  });

  testWidgets('sign in with a wrong password shows the field error', (
    tester,
  ) async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    h.container.read(routerProvider).go(Routes.login);
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(0), 'ayesha@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'nope-nope');
    final button = find.widgetWithText(Pressable, 'Sign in');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);

    expect(
      find.text('Those details do not match an AtomShop account.'),
      findsOneWidget,
    );
    expect(h.container.read(sessionProvider), isA<SignedOut>());
  });

  testWidgets('sign in lands on the from route', (tester) async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    h.container.read(routerProvider).go('/plans/1279');
    await settle(tester);
    expect(location(h), '/login?from=%2Fplans%2F1279');

    await tester.enterText(find.byType(TextField).at(0), '0300 7013707');
    await tester.enterText(
      find.byType(TextField).at(1),
      FakeServer.validPassword,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(h.container.read(sessionProvider), isA<SignedIn>());
    expect(location(h), '/plans/1279');
  });

  testWidgets('a 401 anywhere signs out to Sign in, without looping', (
    tester,
  ) async {
    final h = await Harness.create(token: 'old-token');
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    expect(h.container.read(sessionProvider), isA<SignedIn>());

    // The server forgets the token; the next call gets a 401.
    h.server.signedIn = false;
    // Not awaited: the fake answers on a timer that only runs while pumping.
    ignoreFuture(h.container.read(sessionProvider.notifier).refreshUser());
    await settle(tester);

    expect(h.container.read(sessionProvider), isA<SignedOut>());
    expect(location(h), startsWith(Routes.login));
    expect(find.text("You've been signed out"), findsOneWidget);
  });

  testWidgets('sign up sends a code, then verifies it', (tester) async {
    final h = await Harness.create(scenario: FakeScenario.newCustomer);
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    h.container.read(routerProvider).go(Routes.register);
    await settle(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ayesha Khan');
    await tester.enterText(fields.at(1), '0300 7013707');
    await tester.enterText(fields.at(2), 'password12');
    await tester.enterText(fields.at(3), 'password12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(location(h), Routes.registerVerify);
    expect(find.textContaining('WhatsApp'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '000000');
    await settle(tester);
    expect(find.textContaining("That code isn't right"), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, FakeServer.validCode);
    await settle(tester);
    expect(h.container.read(sessionProvider), isA<SignedIn>());
    expect(location(h), Routes.home);
  });

  testWidgets('forgot password: code, new password, signed in at Home', (
    tester,
  ) async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    h.container.read(routerProvider).go(Routes.forgot);
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'ayesha@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(location(h), Routes.forgotVerify);
    expect(
      find.textContaining('If this belongs to an AtomShop account'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, FakeServer.validCode);
    await settle(tester);
    expect(location(h), Routes.forgotReset);

    await tester.enterText(find.byType(TextField).at(0), 'newpass2026');
    await tester.enterText(find.byType(TextField).at(1), 'newpass2026');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(h.container.read(sessionProvider), isA<SignedIn>());
    expect(location(h), Routes.home);
  });
}
