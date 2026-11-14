import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/core/widgets/product_card.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/home/presentation/home_widgets.dart';
import 'package:atompay_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

Future<Harness> signedInAt(
  WidgetTester tester,
  FakeScenario scenario, {
  Size size = const Size(400, 900),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(scenario: scenario, token: 'token');
  addTearDown(h.dispose);
  await h.pumpApp(tester);
  return h;
}

void main() {
  testWidgets('no limit: the call to apply and the six stages', (tester) async {
    final h = await signedInAt(tester, FakeScenario.newCustomer);
    expect(location(h), Routes.home);
    expect(find.text('Hi Ayesha'), findsOneWidget);
    expect(find.text('Get your AtomPay limit'), findsOneWidget);
    expect(find.text('Where you are'), findsOneWidget);
    expect(find.text('Purchase limit'), findsOneWidget);

    await tester.tap(find.text('Apply for your limit'));
    await settle(tester);
    expect(location(h), Routes.applicationStep(1));
  });

  testWidgets('approved: limit, monthly cap and products that fit', (
    tester,
  ) async {
    await signedInAt(tester, FakeScenario.approved);
    expect(find.textContaining('Your limit is approved'), findsOneWidget);
    expect(find.text('Rs. 60,000'), findsOneWidget);
    expect(find.text('Up to Rs. 20,000 a month'), findsOneWidget);
    expect(find.text('WITHIN YOUR LIMIT'), findsNothing);
    expect(find.text('Within your limit'), findsOneWidget);
    // Figures straight from the server.
    expect(find.byType(ProductCard), findsNWidgets(2));
    expect(find.text('Rs. 15,666'), findsOneWidget);
    expect(find.text('Cash price Rs. 47,000'), findsOneWidget);
    expect(find.text('How to buy with AtomPay'), findsOneWidget);
  });

  testWidgets('repaying: next payment with its three-month bar', (
    tester,
  ) async {
    final h = await signedInAt(tester, FakeScenario.repaying);
    expect(find.text('Rs. 28,666'), findsOneWidget);
    expect(find.text('In use Rs. 31,334'), findsOneWidget);
    expect(find.text('NEXT PAYMENT'), findsOneWidget);
    expect(find.byType(Mini3), findsOneWidget);
    expect(find.textContaining('2nd of 3'), findsOneWidget);
    expect(find.text('Nothing fits Rs. 28,666 right now'), findsOneWidget);

    await tester.tap(find.text('NEXT PAYMENT'));
    await settle(tester);
    expect(location(h), Routes.plan(1279));
  });

  testWidgets('late: the next payment says so', (tester) async {
    await signedInAt(tester, FakeScenario.late);
    expect(find.text('LATE'), findsWidgets);
  });

  testWidgets('tablet: two columns, plan button and the cap note', (
    tester,
  ) async {
    await signedInAt(
      tester,
      FakeScenario.repaying,
      size: const Size(900, 1200),
    );
    expect(find.text('See the plan'), findsOneWidget);
    expect(
      find.text('Each monthly amount fits inside your Rs. 20,000 monthly cap.'),
      findsOneWidget,
    );
  });

  testWidgets('offline with a cached dashboard shows it with the banner', (
    tester,
  ) async {
    final h = await signedInAt(tester, FakeScenario.repaying);
    // The cache now holds the dashboard. Take the network away and reload.
    h.server.offline.add('*');
    h.container.invalidate(dashboardProvider);
    await settle(tester);
    expect(find.text('Rs. 28,666'), findsOneWidget);
    expect(
      find.textContaining("You're offline. Showing your limit from"),
      findsOneWidget,
    );
  });

  testWidgets('offline with nothing cached shows the error state', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(token: 'token');
    addTearDown(h.dispose);
    await h.container.read(responseCacheProvider).clear();
    h.server.offline.add('/dashboard');
    await h.pumpApp(tester);
    expect(find.text("You're offline"), findsOneWidget);
  });

  testWidgets('notifications: grouped, mark all read, tap opens the plan', (
    tester,
  ) async {
    final h = await signedInAt(tester, FakeScenario.repaying);
    await tester.tap(find.bySemanticsLabel('Notifications, 1 unread'));
    await settle(tester);
    expect(location(h), Routes.notifications);
    expect(find.textContaining('TODAY ·'), findsOneWidget);
    expect(find.text('Instalment due in 10 days'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await settle(tester);
    expect(find.text('Mark all read'), findsNothing);
    expect(h.server.notifications.every((n) => n['read'] == true), isTrue);

    await tester.tap(find.text('Instalment due in 10 days'));
    await settle(tester);
    expect(location(h), Routes.plan(1279));
  });

  testWidgets('notifications: empty inbox', (tester) async {
    final h = await signedInAt(tester, FakeScenario.newCustomer);
    h.container.read(routerProvider).go(Routes.notifications);
    await settle(tester);
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
  });

  test('day labels', () {
    final now = DateTime(2026, 11, 10, 15);
    expect(dayLabel(DateTime(2026, 11, 10, 9), now: now), 'Today · 10 Nov');
    expect(dayLabel(DateTime(2026, 11, 9, 9), now: now), 'Yesterday · 9 Nov');
    expect(dayLabel(DateTime(2026, 11, 4, 9), now: now), 'Wednesday · 4 Nov');
    expect(dayLabel(DateTime(2026, 11, 3, 9), now: now), '3 Nov 2026');
    expect(dayLabel(DateTime(2026, 9, 3, 9), now: now), '3 Sep 2026');
  });

  test('ordinals and initials', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal).toList(), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
    ]);
    expect(initialsOf('Ayesha Khan'), 'AK');
    expect(initialsOf('  ayesha  '), 'A');
  });
}
