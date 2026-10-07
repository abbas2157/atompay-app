import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/features/account/domain/account_controllers.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login stores the token and sends the device name', () async {
    final api = FakeApi()
      ..on('POST', '/auth/login', const FakeReply(200, authBody));
    final c = await makeContainer(api);

    final user = await c
        .read(authRepositoryProvider)
        .login(login: ' ayesha@example.com ', password: 'secret-123');

    expect(user.shortName, 'Ayesha K.');
    expect(c.read(tokenStorageProvider).token, '20|atompay_test');
    final body = api.last('POST', '/auth/login')!.data as Map;
    expect(body['login'], 'ayesha@example.com');
    expect(body['device_name'], testDevice.deviceName);
  });

  test('signed-in calls carry the bearer token', () async {
    final api = FakeApi()
      ..on('GET', '/me', const FakeReply(200, {'data': userJson}));
    final c = await makeContainer(api, token: '20|atompay_test');

    await c.read(authControllerProvider.notifier).restore();

    expect(
      api.last('GET', '/me')!.headers['Authorization'],
      'Bearer 20|atompay_test',
    );
    expect(c.read(authControllerProvider), isA<SignedIn>());
  });

  test('a 401 on any signed-in call clears the token and signs out', () async {
    final api = FakeApi()
      ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
      ..on(
        'GET',
        '/profile',
        const FakeReply(401, {'message': 'Unauthenticated.'}),
      );
    final c = await makeContainer(api, token: '20|atompay_test');
    await c.read(authControllerProvider.notifier).restore();

    await expectLater(
      c.read(profileRepositoryProvider).get(),
      throwsA(anything),
    );
    await pumpEventQueue();

    expect(c.read(authControllerProvider), isA<SignedOut>());
    expect(c.read(tokenStorageProvider).token, isNull);
    expect(await c.read(tokenStorageProvider).load(), isNull);
  });

  test('a 403 signs out and keeps the message to show', () async {
    const message = 'Please sign in with an AtomShop customer account.';
    final api = FakeApi()
      ..on('GET', '/me', const FakeReply(200, {'data': userJson}))
      ..on('GET', '/profile', const FakeReply(403, {'message': message}));
    final c = await makeContainer(api, token: '20|atompay_test');
    await c.read(authControllerProvider.notifier).restore();

    await expectLater(
      c.read(profileRepositoryProvider).get(),
      throwsA(anything),
    );
    await pumpEventQueue();

    final state = c.read(authControllerProvider);
    expect(state, isA<SignedOut>());
    expect((state as SignedOut).message, message);
  });

  test('a 403 at sign-in (no token) does not fire a session end', () async {
    final api = FakeApi()
      ..on(
        'POST',
        '/auth/login',
        const FakeReply(403, {'message': 'Not a customer'}),
      );
    final c = await makeContainer(api);
    final before = c.read(authControllerProvider);

    await expectLater(
      c.read(authRepositoryProvider).login(login: 'x@y.z', password: 'p'),
      throwsA(anything),
    );
    await pumpEventQueue();

    expect(c.read(authControllerProvider), same(before));
  });

  test('offline launch falls back to the cached user', () async {
    final api = FakeApi()
      ..on('POST', '/auth/login', const FakeReply(200, authBody));
    final c = await makeContainer(api);
    await c.read(authRepositoryProvider).login(login: 'a@b.c', password: 'p');

    // No route for GET /me → connection error.
    await c.read(authControllerProvider.notifier).restore();

    final state = c.read(authControllerProvider);
    expect(state, isA<SignedIn>());
    expect((state as SignedIn).offline, isTrue);
    expect(state.user.kycStatus, isNotNull);
  });

  test('sign-up returns a challenge, not a token', () async {
    final api = FakeApi()
      ..on(
        'POST',
        '/auth/register',
        const FakeReply(202, {
          'data': {
            'signup_id': 'abc',
            'channel': 'whatsapp',
            'destination': '0300*****67',
            'expires_in': 1799,
            'resend_in': 60,
          },
        }),
      );
    final c = await makeContainer(api);

    final challenge = await c
        .read(authRepositoryProvider)
        .register(
          name: 'Ayesha',
          login: '0300 1234567',
          password: 'secret-123',
          passwordConfirmation: 'secret-123',
        );

    expect(challenge.id, 'abc');
    expect(challenge.channel, CodeChannel.whatsapp);
    expect(c.read(tokenStorageProvider).token, isNull);
  });

  group('delete account', () {
    Future<ProviderContainer> signedIn(FakeApi api) async {
      api.on('GET', '/me', const FakeReply(200, {'data': userJson}));
      final c = await makeContainer(api, token: '20|atompay_test');
      await c.read(authControllerProvider.notifier).restore();
      c.listen(deleteAccountControllerProvider, (_, _) {});
      return c;
    }

    test('sends the password, clears the token and signs out', () async {
      final api = FakeApi()..on('POST', '/me/delete', const FakeReply(204));
      final c = await signedIn(api);

      final ok = await c
          .read(deleteAccountControllerProvider.notifier)
          .delete('secret-123');

      expect(ok, isTrue);
      expect(
        (api.last('POST', '/me/delete')!.data as Map)['password'],
        'secret-123',
      );
      expect(c.read(authControllerProvider), isA<SignedOut>());
      expect(await c.read(tokenStorageProvider).load(), isNull);
    });

    test('a wrong password stays signed in with a field error', () async {
      final api = FakeApi()
        ..on(
          'POST',
          '/me/delete',
          const FakeReply(422, {
            'message': "That password isn't right.",
            'errors': {
              'password': ["That password isn't right."],
            },
          }),
        );
      final c = await signedIn(api);

      final ok = await c
          .read(deleteAccountControllerProvider.notifier)
          .delete('wrong');

      expect(ok, isFalse);
      expect(
        c.read(deleteAccountControllerProvider).field('password'),
        "That password isn't right.",
      );
      expect(c.read(authControllerProvider), isA<SignedIn>());
      expect(c.read(tokenStorageProvider).token, '20|atompay_test');
    });

    test('instalments still owed is a general error', () async {
      const message = 'You still have instalments to pay.';
      final api = FakeApi()
        ..on(
          'POST',
          '/me/delete',
          const FakeReply(409, {
            'message': message,
            'code': 'outstanding_balance',
          }),
        );
      final c = await signedIn(api);

      await c.read(deleteAccountControllerProvider.notifier).delete('pw');

      final status = c.read(deleteAccountControllerProvider);
      expect(status.hasGeneralError, isTrue);
      expect(status.error, isA<Conflict>());
      expect(status.error!.message, message);
      expect(c.read(authControllerProvider), isA<SignedIn>());
    });
  });
}
