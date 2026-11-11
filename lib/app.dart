import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:atompay_mobile/core/router/app_router.dart';
import 'package:atompay_mobile/core/router/deep_links.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/app_theme.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AtomPayApp extends ConsumerStatefulWidget {
  const new({this.listenForLinks = true, super.key});

  /// Off in widget tests (no platform channel).
  final bool listenForLinks;

  @override
  ConsumerState<AtomPayApp> createState() => _AtomPayAppState();
}

class _AtomPayAppState extends ConsumerState<AtomPayApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(launchProvider.notifier).start());
    if (widget.listenForLinks) _listenForLinks();
  }

  /// `https://atompay.shop/app/...`: each passes every guard; signed out it
  /// goes to Sign in, then on to the link.
  void _listenForLinks() {
    try {
      _links = AppLinks().uriLinkStream.listen(openLink);
    } on MissingPluginException {
      // Tests and unsupported platforms.
    }
  }

  void openLink(Uri uri) {
    final router = ref.read(routerProvider);
    final route = routeForLink(uri);
    if (route == null) {
      router.go(Routes.home);
      showToast("That link isn't available", error: true);
      return;
    }
    router.go(route);
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'AtomPay',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        // Text scales to 200% (brief §13); beyond that layouts break.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 2)),
          child: child!,
        );
      },
    );
  }
}
