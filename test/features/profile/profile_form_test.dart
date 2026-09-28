import 'package:atompay_mobile/features/profile/presentation/profile_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

Finder _fieldWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

const _draft = {
  'data': {
    'status': 'not_started',
    'full_name': 'Ayesha Khan',
    'cnic': null,
    'cnic_formatted': null,
    'mobile': '03001234567',
    'mobile_formatted': '0300 1234567',
    'date_of_birth': null,
    'residential_address': null,
    'city': null,
    'documents': {
      'cnic_front': {'uploaded': false, 'url': null},
      'cnic_back': {'uploaded': false, 'url': null},
      'selfie': {'uploaded': false, 'url': null},
    },
    'address_verified': false,
    'verified_at': null,
    'submitted_at': null,
  },
};

void main() {
  testWidgets('pre-fills from AtomShop and demands all 3 photos first time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final api = FakeApi()
      ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
      ..on('GET', '/dashboard', FakeReply(200, dashboardBody()))
      ..on('GET', '/profile', const FakeReply(200, _draft));
    await pumpApp(tester, api, token: '20|atompay_test');

    // Dashboard banner "Apply now" (action: apply) opens the profile form.
    await tester.tap(find.text('Apply now'));
    await settle(tester);
    expect(find.byType(ProfileFormScreen), findsOneWidget);

    // Pre-filled and formatted.
    expect(_fieldWithText('Ayesha Khan'), findsOneWidget);
    expect(_fieldWithText('0300 1234567'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
    await settle(tester);
    expect(find.text('Required.'), findsWidgets); // CNIC, DOB, address
    await tester.scrollUntilVisible(
      find.text('Selfie'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, frames: 3);

    expect(find.text('Add this photo.'), findsNWidgets(3));
    expect(api.last('POST', '/profile'), isNull);
  });
}
