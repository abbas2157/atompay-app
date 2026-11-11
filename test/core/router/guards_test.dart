import 'package:atompay_mobile/core/router/deep_links.dart';
import 'package:atompay_mobile/core/router/guards.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

GuardInput state({
  bool launched = true,
  bool update = false,
  bool maintenance = false,
  bool consented = true,
  bool signedIn = true,
  bool? hasLimit,
  bool onboarded = true,
}) => GuardInput(
  launched: launched,
  updateRequired: update,
  maintenance: maintenance,
  consented: consented,
  signedIn: signedIn,
  hasLimit: hasLimit,
  onboarded: onboarded,
);

String? go(GuardInput s, String location, {Set<String>? limitOnly}) =>
    guardRedirect(
      s,
      Uri.parse(location),
      limitOnly: limitOnly ?? Routes.limitOnly,
    );

void main() {
  test('the dev gallery opens whatever the session state', () {
    for (final s in [
      state(signedIn: false),
      state(consented: false),
      state(),
    ]) {
      expect(go(s, Routes.gallery), isNull);
    }
  });

  group('guards run in the brief §5.3 order', () {
    test('launching holds on the splash and remembers the target', () {
      expect(
        go(state(launched: false), '/plans/1279'),
        '/splash?from=%2Fplans%2F1279',
      );
      expect(go(state(launched: false), Routes.splash), isNull);
    });

    test('1. an old version beats everything', () {
      final s = state(update: true, maintenance: true, consented: false);
      expect(go(s, Routes.home), Routes.update);
      expect(go(s, Routes.update), isNull);
    });

    test('3a. a new install sees the intro slides before First run', () {
      final s = state(onboarded: false, consented: false, signedIn: false);
      expect(go(s, Routes.splash), Routes.onboarding);
      expect(go(s, Routes.onboarding), isNull);
      expect(go(s, Routes.login), '/onboarding?from=%2Flogin');
      // Done: on to First run.
      expect(
        go(state(consented: false, signedIn: false), Routes.onboarding),
        Routes.firstRun,
      );
    });

    test('3a. maintenance beats the intro slides', () {
      final s = state(maintenance: true, onboarded: false, consented: false);
      expect(go(s, Routes.onboarding), Routes.maintenance);
    });

    test('3a. never shown again once the disclosures are accepted', () {
      final s = state(onboarded: false, signedIn: false);
      expect(go(s, Routes.onboarding), Routes.welcome);
    });

    test('2. maintenance beats consent and sign-in', () {
      final s = state(maintenance: true, consented: false, signedIn: false);
      expect(go(s, '/plans/5'), '/maintenance?from=%2Fplans%2F5');
      expect(go(s, Routes.maintenance), isNull);
    });

    test('3. no consent shows First run before sign-in', () {
      final s = state(consented: false, signedIn: false);
      expect(go(s, Routes.login), '/first-run?from=%2Flogin');
      expect(go(s, Routes.firstRun), isNull);
    });

    test('4. no token goes to Sign in with from', () {
      final s = state(signedIn: false);
      expect(go(s, '/plans/1279'), '/login?from=%2Fplans%2F1279');
      expect(go(s, Routes.login), isNull);
      expect(go(s, Routes.forgotVerify), isNull);
    });

    test('a gate that clears carries its from on to Sign in', () {
      final s = state(signedIn: false);
      expect(
        go(s, '/maintenance?from=%2Fplans%2F5'),
        '/login?from=%2Fplans%2F5',
      );
      expect(go(s, Routes.splash), Routes.welcome);
    });

    test('signed in after a 401 lands on the from route', () {
      expect(go(state(), '/login?from=%2Fplans%2F1279'), '/plans/1279');
    });

    test('from never loops back into auth or leaves the app', () {
      expect(go(state(), '/login?from=%2Flogin'), Routes.home);
      expect(
        go(state(), '/login?from=https%3A%2F%2Fevil.example'),
        Routes.home,
      );
      expect(go(state(), '/login?from=%2F%2Fevil.example'), Routes.home);
    });

    test('signed in, launch and auth screens go Home', () {
      expect(go(state(), Routes.splash), Routes.home);
      expect(go(state(), Routes.welcome), Routes.home);
      expect(go(state(), Routes.maintenance), Routes.home);
      expect(go(state(), Routes.home), isNull);
    });

    test('6. a limit-only route without a limit goes Home', () {
      const only = {'/limit-only'};
      expect(
        go(state(hasLimit: false), '/limit-only', limitOnly: only),
        Routes.home,
      );
      expect(go(state(hasLimit: true), '/limit-only', limitOnly: only), isNull);
      expect(go(state(), '/limit-only', limitOnly: only), isNull);
    });
  });

  group('deep links (brief §5.5)', () {
    Uri link(String path) => Uri.parse('https://atompay.shop$path');

    test('each documented link maps to its route', () {
      expect(routeForLink(link('/app')), Routes.home);
      expect(routeForLink(link('/app/orders/1043')), '/plans/1043');
      expect(routeForLink(link('/app/orders/1043/kfs')), '/plans/1043/kfs');
      expect(routeForLink(link('/app/apply')), '/application?step=1');
      expect(routeForLink(link('/app/application')), Routes.applicationStatus);
      expect(routeForLink(link('/app/notifications')), Routes.notifications);
      expect(routeForLink(link('/app/ask')), Routes.atom);
      expect(routeForLink(link('/app/account')), Routes.account);
    });

    test('unknown links are refused', () {
      expect(routeForLink(link('/app/orders/abc')), isNull);
      expect(routeForLink(link('/app/secret')), isNull);
      expect(routeForLink(link('/shop')), isNull);
    });

    test('push data uses the same table', () {
      expect(routeForPush({'screen': 'dashboard'}), Routes.home);
      expect(
        routeForPush({'screen': 'plan', 'order_id': '1043'}),
        '/plans/1043',
      );
      expect(routeForPush({'screen': 'plan', 'order_id': 1043}), '/plans/1043');
      expect(routeForPush({'screen': 'profile'}), Routes.account);
      expect(routeForPush({'screen': 'mystery'}), Routes.home);
    });
  });
}
