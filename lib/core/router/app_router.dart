import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/router/guards.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/router/screens.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/help/data/help_content.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Whether the customer has a limit in force; null until `/dashboard` has
/// loaded.
final hasLimitProvider = Provider<bool?>(
  (ref) => ref.watch(dashboardHasLimitProvider),
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..listen(launchProvider, (_, _) => refresh.value++)
    ..listen(consentProvider, (_, _) => refresh.value++)
    ..listen(hasLimitProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  GuardInput input() {
    final launch = ref.read(launchProvider);
    return GuardInput(
      launched: launch.ready,
      updateRequired: launch.updateRequired,
      maintenance: launch.maintenance,
      consented: ref.read(consentProvider),
      signedIn: ref.read(sessionProvider) is SignedIn,
      hasLimit: ref.read(hasLimitProvider),
    );
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => guardRedirect(input(), state.uri),
    errorBuilder: (_, _) => const NotFoundRedirect(),
    routes: buildRoutes(rootNavigatorKey),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// The whole route table (brief §5). Kept apart from the provider so tests
/// can build a router over it.
List<RouteBase> buildRoutes(GlobalKey<NavigatorState> root) {
  int? intParam(GoRouterState s, String name) =>
      int.tryParse(s.pathParameters[name] ?? '');

  return [
    // Launch
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: Routes.update,
      builder: (_, _) => const UpdateRequiredScreen(),
    ),
    GoRoute(
      path: Routes.maintenance,
      builder: (_, _) => const MaintenanceScreen(),
    ),
    GoRoute(path: Routes.firstRun, builder: (_, _) => const FirstRunScreen()),
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    if (!Env.isProd)
      GoRoute(path: Routes.gallery, builder: (_, _) => const GalleryScreen()),

    // Auth
    GoRoute(path: Routes.login, builder: (_, _) => const SignInScreen()),
    GoRoute(
      path: Routes.register,
      builder: (_, _) => const SignUpScreen(),
      routes: [
        GoRoute(path: 'verify', builder: (_, _) => const VerifyCodeScreen()),
      ],
    ),
    GoRoute(
      path: Routes.forgot,
      builder: (_, _) => const ForgotScreen(),
      routes: [
        GoRoute(path: 'verify', builder: (_, _) => const ForgotCodeScreen()),
        GoRoute(path: 'reset', builder: (_, _) => const NewPasswordScreen()),
      ],
    ),

    // Ask Atom: full screen over the current tab.
    GoRoute(
      path: Routes.atom,
      parentNavigatorKey: root,
      pageBuilder: (_, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const AskAtomScreen(),
      ),
    ),

    // Camera capture: full screen, no tab bar.
    GoRoute(
      path: '/application/capture/:doc',
      parentNavigatorKey: root,
      redirect: (_, s) => CaptureDoc.parse(s.pathParameters['doc']) == null
          ? Routes.application
          : null,
      builder: (_, s) =>
          CaptureScreen(doc: CaptureDoc.parse(s.pathParameters['doc'])!),
    ),

    StatefulShellRoute(
      builder: (_, _, shell) => shell,
      navigatorContainerBuilder: (_, shell, children) =>
          AppShell(shell: shell, children: children),
      branches: [
        // Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  builder: (_, _) => const NotificationsScreen(),
                ),
              ],
            ),
            GoRoute(
              path: Routes.application,
              builder: (_, s) => ApplyScreen(
                step: int.tryParse(s.uri.queryParameters['step'] ?? '') ?? 1,
                edit: s.uri.queryParameters['edit'] == '1',
              ),
            ),
            // Siblings, not children, of the wizard: "Application sent"
            // goes here with the wizard removed (brief §5.6).
            GoRoute(
              path: Routes.applicationStatus,
              builder: (_, _) => const VerificationScreen(),
            ),
            GoRoute(
              path: Routes.applicationHistory,
              builder: (_, _) => const ApplicationHistoryScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  redirect: (_, s) => intParam(s, 'id') == null
                      ? Routes.applicationHistory
                      : null,
                  builder: (_, s) =>
                      ApplicationDetailScreen(id: intParam(s, 'id')!),
                ),
              ],
            ),
            GoRoute(
              path: '/profile/document/:doc',
              redirect: (_, s) =>
                  CaptureDoc.parse(s.pathParameters['doc']) == null
                  ? Routes.applicationStatus
                  : null,
              builder: (_, s) => DocumentViewerScreen(
                doc: CaptureDoc.parse(s.pathParameters['doc'])!,
              ),
            ),
          ],
        ),

        // Shop
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.shop,
              builder: (_, _) => const ShopScreen(),
              routes: [
                GoRoute(
                  path: ':productId',
                  redirect: (_, s) =>
                      intParam(s, 'productId') == null ? Routes.shop : null,
                  builder: (_, s) =>
                      ProductScreen(productId: intParam(s, 'productId')!),
                ),
              ],
            ),
            GoRoute(
              path: Routes.calculator,
              builder: (_, _) => const CalculatorScreen(),
            ),
          ],
        ),

        // Orders
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.plans,
              builder: (_, _) => const OrdersScreen(),
              routes: [
                GoRoute(
                  path: ':orderId',
                  redirect: (_, s) =>
                      intParam(s, 'orderId') == null ? Routes.plans : null,
                  builder: (_, s) =>
                      OrderDetailScreen(orderId: intParam(s, 'orderId')!),
                  routes: [
                    GoRoute(
                      path: 'kfs',
                      builder: (_, s) =>
                          KfsScreen(orderId: intParam(s, 'orderId')!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Account and Help
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.account,
              builder: (_, _) => const AccountScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (_, _) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'security',
                      builder: (_, _) => const SecurityScreen(),
                    ),
                    GoRoute(
                      path: 'permissions',
                      builder: (_, _) => const PermissionsScreen(),
                    ),
                    GoRoute(
                      path: 'notifications',
                      builder: (_, _) => const NotificationSettingsScreen(),
                    ),
                    GoRoute(
                      path: 'password',
                      builder: (_, _) => const ChangePasswordScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'devices',
                  builder: (_, _) => const DevicesScreen(),
                ),
                GoRoute(
                  path: 'delete',
                  builder: (_, _) => const DeleteAccountScreen(),
                ),
                GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                GoRoute(
                  path: 'ecosystem',
                  builder: (_, _) => const EcosystemScreen(),
                ),
                GoRoute(path: 'rate', builder: (_, _) => const RateUsScreen()),
              ],
            ),
            GoRoute(
              path: Routes.help,
              builder: (_, _) => const HelpScreen(),
              routes: [
                GoRoute(
                  path: 'topic/:topic',
                  redirect: (_, s) {
                    final topic = s.pathParameters['topic'];
                    return topic == HelpContent.all ||
                            HelpContent.topic(topic ?? '') != null
                        ? null
                        : Routes.help;
                  },
                  builder: (_, s) => HelpTopicScreen(
                    topic: s.pathParameters['topic']!,
                    question: s.uri.queryParameters['q'],
                    search: s.uri.queryParameters['search'] == '1',
                  ),
                ),
                GoRoute(
                  path: 'complaint',
                  builder: (_, _) => const ComplaintScreen(),
                  routes: [
                    GoRoute(
                      path: 'sent',
                      builder: (_, s) => ComplaintSentScreen(
                        reference: s.uri.queryParameters['ref'] ?? '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
