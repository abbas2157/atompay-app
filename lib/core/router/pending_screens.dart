// The unknown-path fallback. Every screen of the brief is built.

import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Unknown paths go Home with "That link isn't available".
class NotFoundRedirect extends StatefulWidget {
  const new({super.key});

  @override
  State<NotFoundRedirect> createState() => _NotFoundRedirectState();
}

class _NotFoundRedirectState extends State<NotFoundRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showToast("That link isn't available", error: true);
      context.go(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
