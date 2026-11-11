import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

void main() {
  testWidgets('the gallery renders every component without errors', (
    tester,
  ) async {
    final h = await Harness.create(consented: false);
    addTearDown(h.dispose);
    await h.pumpApp(tester);
    h.container.read(routerProvider).go(Routes.gallery);
    await settle(tester);

    expect(find.text('Widget gallery'), findsOneWidget);
    // Scroll to the end: every section builds and lays out.
    // Section labels are upper case.
    final last = find.text('RETRY COUNTDOWN');
    await tester.scrollUntilVisible(
      last,
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester, frames: 5);
    expect(last, findsOneWidget);
  });
}
