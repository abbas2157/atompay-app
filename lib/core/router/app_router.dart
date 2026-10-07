import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/account/presentation/account_screens.dart';
import 'package:atompay_mobile/features/application/presentation/application_form_screen.dart';
import 'package:atompay_mobile/features/application/presentation/application_status_screen.dart';
import 'package:atompay_mobile/features/application/presentation/estimator_screen.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/auth/presentation/forgot_screens.dart';
import 'package:atompay_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:atompay_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:atompay_mobile/features/auth/presentation/sign_up_verify_screen.dart';
import 'package:atompay_mobile/features/calculator/presentation/calculator_screen.dart';
import 'package:atompay_mobile/features/dashboard/presentation/home_screen.dart';
import 'package:atompay_mobile/features/guest/presentation/welcome_screen.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:atompay_mobile/features/launch/presentation/launch_screens.dart';
import 'package:atompay_mobile/features/notifications/presentation/inbox_screen.dart';
import 'package:atompay_mobile/features/plans/presentation/plan_detail_screen.dart';
import 'package:atompay_mobile/features/plans/presentation/plans_screen.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_form_screen.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever launch or auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, _) => refresh.value++)
    ..listen(launchControllerProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      launch: ref.read(launchControllerProvider),
      auth: ref.read(authControllerProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.update,
        builder: (_, _) => const UpdateRequiredScreen(),
      ),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const SignUpScreen(),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (_, _) => const SignUpVerifyScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.forgot,
        builder: (_, state) =>
            ForgotScreen(initialLogin: state.extra as String?),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (_, _) => const ForgotVerifyScreen(),
          ),
          GoRoute(path: 'reset', builder: (_, _) => const ForgotResetScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const InboxScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plans,
                builder: (_, _) => const PlansScreen(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    parentNavigatorKey: _rootKey,
                    redirect: (_, state) =>
                        int.tryParse(state.pathParameters['orderId']!) == null
                        ? Routes.plans
                        : null,
                    builder: (_, state) => PlanDetailScreen(
                      orderId: int.parse(state.pathParameters['orderId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => ProfileFormScreen(
                      thenApply:
                          state.uri.queryParameters['next'] == 'application',
                    ),
                  ),
                  GoRoute(
                    path: 'document/:doc',
                    parentNavigatorKey: _rootKey,
                    redirect: (_, state) =>
                        ProfileDocument.parse(state.pathParameters['doc']!) ==
                            null
                        ? Routes.profile
                        : null,
                    builder: (_, state) => DocumentViewerScreen(
                      document: ProfileDocument.parse(
                        state.pathParameters['doc']!,
                      )!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.application,
        builder: (_, _) => const ApplicationFormScreen(),
        routes: [
          GoRoute(
            path: 'status',
            builder: (_, _) => const ApplicationStatusScreen(),
          ),
          GoRoute(
            path: 'history',
            builder: (_, _) => const ApplicationHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.estimate,
        builder: (_, _) => const EstimatorScreen(),
      ),
      GoRoute(
        path: Routes.calculator,
        builder: (_, _) => const CalculatorScreen(),
      ),
      GoRoute(
        path: Routes.account,
        builder: (_, _) => const AccountScreen(),
        routes: [
          GoRoute(path: 'devices', builder: (_, _) => const DevicesScreen()),
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: 'delete',
            builder: (_, _) => const DeleteAccountScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// The auth guard (handbook §3.5), pure so it can be unit tested.
String? redirectFor({
  required LaunchState launch,
  required AuthState auth,
  required String location,
}) {
  String? to(String target) => location == target ? null : target;

  if (launch is UpdateRequired) return to(Routes.update);
  if (launch is Launching || auth is AuthUnknown || auth is AuthOffline) {
    return to(Routes.splash);
  }
  if (auth is! SignedIn) {
    final open =
        Routes.signedOutOnly.contains(location) ||
        Routes.passwordReset.contains(location) ||
        Routes.public.contains(location);
    return open ? null : Routes.welcome;
  }
  if (Routes.signedOutOnly.contains(location) ||
      Routes.launch.contains(location)) {
    return Routes.home;
  }
  return null;
}
