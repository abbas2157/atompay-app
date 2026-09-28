import 'package:atompay_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:atompay_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:atompay_mobile/features/auth/presentation/sign_up_verify_screen.dart';
import 'package:atompay_mobile/features/dashboard/presentation/home_screen.dart';
import 'package:atompay_mobile/features/guest/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

const _challenge = {
  'data': {
    'signup_id': 'signup-1',
    'channel': 'whatsapp',
    'destination': '0300*****67',
    'expires_in': 1799,
    'resend_in': 60,
  },
};

Future<void> _tap(WidgetTester tester, String text) async {
  // ListView builds lazily: bring the button into existence first.
  await tester.scrollUntilVisible(
    find.text(text).last,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  final button = find
      .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      )
      .last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

void main() {
  group('Sign in', () {
    testWidgets('launch without a token lands on the guest home', (
      tester,
    ) async {
      await pumpApp(tester, FakeApi());
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);

      await goToSignIn(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Sign in with your AtomShop account'), findsOneWidget);
    });

    testWidgets('a 422 shows under the login field', (tester) async {
      final api = FakeApi()
        ..on(
          'POST',
          '/auth/login',
          const FakeReply(422, {
            'message': 'Invalid.',
            'errors': {
              'login': ['Those details do not match an AtomShop account.'],
            },
          }),
        );
      await pumpApp(tester, api);
      await goToSignIn(tester);

      await enterField(tester, 'Email or mobile number', 'ayesha@example.com');
      await enterField(tester, 'Password', 'wrong-pass');
      await _tap(tester, 'Sign in');

      expect(
        find.text('Those details do not match an AtomShop account.'),
        findsOneWidget,
      );
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('client checks run before calling the server', (tester) async {
      final api = FakeApi();
      await pumpApp(tester, api);
      await goToSignIn(tester);

      await enterField(tester, 'Email or mobile number', '021 34567890');
      await _tap(tester, 'Sign in');

      expect(
        find.text('Enter a mobile number, e.g. 0300 1234567.'),
        findsOneWidget,
      );
      expect(find.text('Required.'), findsOneWidget);
      expect(api.last('POST', '/auth/login'), isNull);
    });

    testWidgets('a 403 shows the server message and no token', (tester) async {
      const message = 'Please sign in with an AtomShop customer account.';
      final api = FakeApi()
        ..on('POST', '/auth/login', const FakeReply(403, {'message': message}));
      await pumpApp(tester, api);
      await goToSignIn(tester);

      await enterField(tester, 'Email or mobile number', 'staff@atompay.shop');
      await enterField(tester, 'Password', 'secret-123');
      await _tap(tester, 'Sign in');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets('a 429 counts down and disables the button', (tester) async {
      final api = FakeApi()
        ..on(
          'POST',
          '/auth/login',
          const FakeReply(
            429,
            {'message': 'Too Many Attempts.'},
            {'retry-after': '30'},
          ),
        );
      await pumpApp(tester, api);
      await goToSignIn(tester);

      await enterField(tester, 'Email or mobile number', 'a@b.co');
      await enterField(tester, 'Password', 'secret-123');
      await _tap(tester, 'Sign in');

      expect(find.textContaining('Too many attempts. Try again in'), findsOne);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('success lands on Home', (tester) async {
      final api = FakeApi()
        ..on('POST', '/auth/login', const FakeReply(200, authBody));
      await pumpApp(tester, api);
      await goToSignIn(tester);

      await enterField(tester, 'Email or mobile number', '0300 1234567');
      await enterField(tester, 'Password', 'secret-123');
      await _tap(tester, 'Sign in');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Hi, Ayesha K.'), findsOneWidget);
      final body = api.last('POST', '/auth/login')!.data as Map;
      expect(body['login'], '0300 1234567');
    });
  });

  group('Sign up', () {
    Future<void> fillDetails(WidgetTester tester) async {
      await tester.tap(find.text('Create account'));
      await settle(tester);
      await enterField(tester, 'Full name', 'Ayesha Khan');
      await enterField(tester, 'Email or mobile number', '03001234567');
      await enterField(tester, 'Password', 'secret-123');
      await enterField(tester, 'Confirm password', 'secret-123');
    }

    testWidgets('the hint follows what is typed', (tester) async {
      await pumpApp(tester, FakeApi());
      await tester.tap(find.text('Create account'));
      await settle(tester);

      await enterField(tester, 'Email or mobile number', 'ayesha@');
      expect(find.text("We'll email you a code."), findsOneWidget);

      await enterField(tester, 'Email or mobile number', '0300');
      expect(find.text("We'll send the code on WhatsApp."), findsOneWidget);
    });

    testWidgets('code screen: wrong code, then sign-up expired → back', (
      tester,
    ) async {
      final api = FakeApi()
        ..on('POST', '/auth/register', const FakeReply(202, _challenge));
      await pumpApp(tester, api);
      await fillDetails(tester);
      await _tap(tester, 'Send code');

      expect(find.byType(SignUpVerifyScreen), findsOneWidget);
      expect(
        find.text('We sent a 6-digit code to 0300*****67 on WhatsApp.'),
        findsOneWidget,
      );
      expect(find.textContaining('Send a new code in'), findsOneWidget);

      api.on(
        'POST',
        '/auth/register/verify',
        const FakeReply(422, {
          'message': 'x',
          'errors': {
            'code': ["That code isn't right. 4 tries left."],
          },
        }),
      );
      await tester.enterText(find.byType(TextField), '111111');
      await settle(tester);
      expect(find.text("That code isn't right. 4 tries left."), findsOneWidget);

      api.on(
        'POST',
        '/auth/register/verify',
        const FakeReply(422, {
          'message': 'x',
          'errors': {
            'signup': ['This sign-up has expired. Please start again.'],
          },
        }),
      );
      await tester.enterText(find.byType(TextField), '222222');
      await settle(tester);
      expect(
        find.text('This sign-up has expired. Please start again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await settle(tester);

      // Back on the details screen with the values kept.
      expect(find.byType(SignUpScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('FULL NAME'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ayesha Khan'), findsOneWidget);
    });

    testWidgets('the right code signs in', (tester) async {
      final api = FakeApi()
        ..on('POST', '/auth/register', const FakeReply(202, _challenge))
        ..on('POST', '/auth/register/verify', const FakeReply(201, authBody));
      await pumpApp(tester, api);
      await fillDetails(tester);
      await _tap(tester, 'Send code');

      await tester.enterText(find.byType(TextField), '482913');
      await settle(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      final body = api.last('POST', '/auth/register/verify')!.data as Map;
      expect(body['signup_id'], 'signup-1');
      expect(body['code'], '482913');
    });
  });

  group('Forgot password', () {
    const request = {
      'data': {
        'request_id': 'req-1',
        'channel': 'email',
        'destination': 'no****@example.com',
        'expires_in': 599,
        'resend_in': 60,
      },
    };

    testWidgets('neutral wording, then reset signs in with a toast', (
      tester,
    ) async {
      final api = FakeApi()
        ..on('POST', '/auth/password/forgot', const FakeReply(202, request))
        ..on(
          'POST',
          '/auth/password/verify',
          const FakeReply(200, {
            'data': {'reset_token': 'tok', 'expires_in': 900},
          }),
        )
        ..on('POST', '/auth/password/reset', const FakeReply(200, authBody));
      await pumpApp(tester, api);
      await goToSignIn(tester);
      await tester.tap(find.text('Forgot password?'));
      await settle(tester);
      await enterField(tester, 'Email or mobile number', 'nobody@example.com');
      await _tap(tester, 'Send code');

      expect(
        find.text(
          "If this belongs to an AtomShop account, we've sent a code to "
          'no****@example.com.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No account'), findsNothing);

      await tester.enterText(find.byType(TextField), '863230');
      await settle(tester);
      await enterField(tester, 'New password', 'new-pass-456');
      await enterField(tester, 'Confirm password', 'new-pass-456');
      await _tap(tester, 'Save password');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.text('Password changed. It works on AtomShop.pk too.'),
        findsOneWidget,
      );
    });

    testWidgets('too many wrong codes goes back to step 1', (tester) async {
      final api = FakeApi()
        ..on('POST', '/auth/password/forgot', const FakeReply(202, request))
        ..on(
          'POST',
          '/auth/password/verify',
          const FakeReply(422, {
            'message': 'x',
            'errors': {
              'code': ['Too many wrong codes. Request a new one.'],
            },
          }),
        );
      await pumpApp(tester, api);
      await goToSignIn(tester);
      await tester.tap(find.text('Forgot password?'));
      await settle(tester);
      await enterField(tester, 'Email or mobile number', 'a@b.co');
      await _tap(tester, 'Send code');

      await tester.enterText(find.byType(TextField), '000000');
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(find.text('Reset your password'), findsOneWidget);
    });
  });

  testWidgets('a revoked token returns to sign in without a crash', (
    tester,
  ) async {
    final api = FakeApi()
      ..on('GET', '/me', const FakeReply(200, {'data': userJson}));
    await pumpApp(tester, api, token: '20|atompay_test');
    expect(find.byType(HomeScreen), findsOneWidget);

    // "Sign out everywhere" on another phone: every call now 401s.
    api.on('GET', '/me', const FakeReply(401, {'message': 'Unauthenticated.'}));
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await settle(tester, frames: 30);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
