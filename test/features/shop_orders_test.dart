import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/widgets/product_card.dart';
import 'package:atompay_mobile/features/plans/application/plans_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/presentation/kfs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

String location(Harness h) =>
    h.container.read(routerProvider).state.uri.toString();

Future<Harness> at(
  WidgetTester tester,
  String route, {
  FakeScenario scenario = FakeScenario.repaying,
}) async {
  tester.view
    ..physicalSize = const Size(420, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(scenario: scenario, token: 'token');
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

void main() {
  group('Shop', () {
    testWidgets('lists eligible products and filters by category', (
      tester,
    ) async {
      await at(tester, Routes.shop, scenario: FakeScenario.approved);
      expect(find.text('Eligible products'), findsOneWidget);
      expect(find.byType(ProductCard), findsWidgets);
      expect(find.text('Cash price Rs. 47,000'), findsOneWidget);
      expect(find.text('Cash price Rs. 53,995'), findsOneWidget);

      await tapText(tester, 'Phones');
      expect(find.text('Cash price Rs. 47,000'), findsNothing);
      expect(find.text('Cash price Rs. 53,995'), findsOneWidget);
    });

    testWidgets('fits my limit: empty, then show all', (tester) async {
      await at(tester, Routes.shop);
      await tapText(tester, 'Fits my limit');
      expect(find.text('Nothing here right now'), findsOneWidget);
      await tapText(tester, 'Show all products');
      expect(find.byType(ProductCard), findsWidgets);
    });

    testWidgets('the product plan shows the server figures exactly', (
      tester,
    ) async {
      await at(tester, Routes.product(51), scenario: FakeScenario.approved);
      expect(find.text('OXY 3218L Android'), findsOneWidget);
      expect(find.text('Cash price Rs. 47,000'), findsOneWidget);
      expect(find.text('Rs. 15,666'), findsNWidgets(2));
      expect(find.text('MONTH 3 · TAKES THE ROUNDING'), findsOneWidget);
      expect(find.text('Rs. 15,668'), findsOneWidget);
      expect(find.text('Rs. 47,000'), findsOneWidget);
      expect(find.text('Rs. 0'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(
        find.textContaining('A 3% processing fee (Rs. 1,410)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Fits your limit. Rs. 60,000 available, and Rs. 15,666 a month is '
          'under your Rs. 20,000 cap.',
        ),
        findsOneWidget,
      );
      expect(find.text('Buy on Atomshop.pk'), findsOneWidget);
    });

    testWidgets('a product that is not eligible says so', (tester) async {
      await at(tester, Routes.product(9999));
      expect(find.text("This product isn't eligible"), findsOneWidget);
    });

    testWidgets('calculator: price in, three months out', (tester) async {
      await at(tester, Routes.calculator);
      await tester.enterText(find.byType(TextField).first, '47000');
      await settle(tester, frames: 10);
      expect(find.text('47,000'), findsOneWidget);
      expect(find.text('PER MONTH × 3'), findsOneWidget);
      expect(find.text('Rs. 15,668'), findsOneWidget);
      expect(find.textContaining('(Rs. 1,410)'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '500');
      await settle(tester, frames: 10);
      expect(find.text('Enter a price of at least Rs. 1,000.'), findsOneWidget);
    });
  });

  group('Orders', () {
    testWidgets('list, detail and schedule', (tester) async {
      final h = await at(tester, Routes.plans);
      expect(find.text('My orders'), findsOneWidget);
      expect(find.text('OXY 3218L Android'), findsOneWidget);
      expect(find.text('REPAYING'), findsOneWidget);
      expect(find.text('Rs. 15,666 of Rs. 47,000 paid'), findsOneWidget);

      await tapText(tester, 'OXY 3218L Android');
      expect(location(h), Routes.plan(1279));
      expect(find.text('AS-01279'), findsOneWidget);
      // Total, paid and to go are the server's progress figures.
      expect(find.text('Rs. 47,000'), findsOneWidget);
      expect(find.text('Rs. 31,334'), findsOneWidget);
      expect(find.text('1st Instalment'), findsOneWidget);
      expect(find.text('3rd Instalment'), findsOneWidget);
      expect(find.textContaining('takes the rounding'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);

      await tapText(tester, 'Key Fact Statement');
      expect(location(h), Routes.kfs(1279));
    });

    testWidgets('late: what was missed, and Talk to us', (tester) async {
      await at(tester, Routes.plan(1279), scenario: FakeScenario.late);
      expect(find.text('LATE'), findsWidgets);
      expect(find.textContaining('Was due on'), findsOneWidget);
      expect(find.text('[CHARGES, IF ANY]'), findsOneWidget);
      expect(find.text('Talk to us'), findsOneWidget);
    });

    testWidgets('no orders yet', (tester) async {
      await at(tester, Routes.plans, scenario: FakeScenario.approved);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('See eligible products'), findsOneWidget);
    });

    testWidgets('an order that is not yours', (tester) async {
      await at(tester, Routes.plan(4040));
      expect(find.text("We can't find this order"), findsOneWidget);
      expect(find.text('Go to my orders'), findsOneWidget);
    });

    testWidgets('KFS: placeholders stay visible; email a copy', (tester) async {
      await at(tester, Routes.kfs(1279));
      expect(
        find.text('[LICENSED ENTITY NAME] · SECP licence [NO.]'),
        findsOneWidget,
      );
      expect(find.text('3% · Rs. 1,410'), findsOneWidget);
      expect(find.text('[confirm it is charged]'), findsOneWidget);
      expect(find.text('18.5% including the fee'), findsOneWidget);
      expect(find.text('[0% if no fee is charged]'), findsOneWidget);
      expect(find.text('[EARLY SETTLEMENT TERMS]'), findsOneWidget);
      expect(find.text('Rs. 47,000 in instalments'), findsOneWidget);

      await tapText(tester, 'Email or SMS me a copy');
      await tapText(tester, 'Email me a copy');
      expect(find.text('We have emailed you a copy'), findsOneWidget);
    });
  });

  test('order badges follow the canvas', () {
    Plan plan(String state, {String? status}) => Plan(
      order: PlanOrder(id: 1, reference: 'AS-1', totalPrice: 1, status: status),
      state: state,
    );
    expect(
      OrderBadge.of(plan('pending', status: 'Pending')).label,
      'Awaiting approval',
    );
    expect(
      OrderBadge.of(plan('pending', status: 'Varification')).label,
      'Verification',
    );
    expect(
      OrderBadge.of(plan('processing', status: 'Delivered')).label,
      'Delivered',
    );
    expect(
      OrderBadge.of(plan('processing', status: 'Processing')).label,
      'Processing',
    );
    expect(OrderBadge.of(plan('on_track')).label, 'Repaying');
    expect(OrderBadge.of(plan('late')).hasSchedule, isTrue);
    expect(OrderBadge.of(plan('completed')).hasSchedule, isFalse);
    expect(OrderBadge.of(plan('cancelled')).label, 'Cancelled');
  });

  test('the shared KFS keeps every placeholder', () {
    final text = kfsText(
      Kfs(
        orderNumber: 'AS-01279',
        amountFinanced: 47000,
        months: 3,
        totalRepayable: 47000,
        processingFeePercent: 3,
        processingFee: 1410,
        aprPercent: 18.5,
        instalments: [
          KfsInstalment(
            number: 1,
            dueDate: DateTime(2026, 12, 10),
            amount: 15666,
          ),
        ],
      ),
    );
    expect(text, contains('[LICENSED ENTITY NAME]'));
    expect(text, contains('[CHARGES, IF ANY]'));
    expect(text, contains('Instalment 1: 10 Dec 2026 · Rs. 15,666'));
  });
}
