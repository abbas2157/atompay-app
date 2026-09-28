import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/utils/versions.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = User(id: 1, name: 'A', shortName: 'A', email: null);

void main() {
  group('redirectFor', () {
    String? go(LaunchState launch, AuthState auth, String at) =>
        redirectFor(launch: launch, auth: auth, location: at);

    test('holds on splash while launching', () {
      expect(
        go(const Launching(), const AuthUnknown(), Routes.home),
        Routes.splash,
      );
      expect(go(const Launching(), const AuthUnknown(), Routes.splash), isNull);
    });

    test('update required blocks everything', () {
      expect(
        go(const UpdateRequired(null), const SignedIn(_user), Routes.home),
        Routes.update,
      );
    });

    test('offline with nothing cached stays on splash', () {
      expect(
        go(const Launched(), const AuthOffline(), Routes.home),
        Routes.splash,
      );
    });

    test('signed out: guest home, auth and public tools only', () {
      const out = SignedOut();
      expect(go(const Launched(), out, Routes.home), Routes.welcome);
      expect(go(const Launched(), out, Routes.profileEdit), Routes.welcome);
      expect(go(const Launched(), out, Routes.splash), Routes.welcome);
      expect(go(const Launched(), out, Routes.welcome), isNull);
      expect(go(const Launched(), out, Routes.calculator), isNull);
      expect(go(const Launched(), out, Routes.login), isNull);
      expect(go(const Launched(), out, Routes.registerVerify), isNull);
      expect(go(const Launched(), out, Routes.forgotReset), isNull);
    });

    test('signed in: auth-only and launch routes go Home', () {
      const inn = SignedIn(_user);
      expect(go(const Launched(), inn, Routes.login), Routes.home);
      expect(go(const Launched(), inn, Routes.welcome), Routes.home);
      expect(go(const Launched(), inn, Routes.registerVerify), Routes.home);
      expect(go(const Launched(), inn, Routes.splash), Routes.home);
      expect(go(const Launched(), inn, Routes.profile), isNull);
      // Account → Change password uses the reset flow while signed in.
      expect(go(const Launched(), inn, Routes.forgot), isNull);
    });
  });

  group('isBelowMinVersion', () {
    test('compares semver and ignores build numbers', () {
      expect(isBelowMinVersion('1.0.0', '1.0.1'), isTrue);
      expect(isBelowMinVersion('1.2.0+7', '1.2.0'), isFalse);
      expect(isBelowMinVersion('2.0.0', '1.9.9'), isFalse);
    });

    test('flavour suffixes do not count as pre-releases', () {
      // Android reports the dev flavour's version as `1.0.0-dev`.
      expect(isBelowMinVersion('1.0.0-dev', '1.0.0'), isFalse);
      expect(isBelowMinVersion('1.0.0-staging+3', '1.0.0'), isFalse);
      expect(isBelowMinVersion('1.0.0-dev', '1.0.1'), isTrue);
    });

    test('never blocks on missing or bad input', () {
      expect(isBelowMinVersion('1.0.0', null), isFalse);
      expect(isBelowMinVersion('1.0.0', ''), isFalse);
      expect(isBelowMinVersion('1.0.0', 'banana'), isFalse);
    });
  });
}
