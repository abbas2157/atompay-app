import 'package:atompay_mobile/core/router/routes.dart';
import 'package:flutter/foundation.dart';

/// Everything the guards look at, gathered so [guardRedirect] is a pure
/// function the tests can drive.
@immutable
class GuardInput {
  const new({
    required this.launched,
    required this.updateRequired,
    required this.maintenance,
    required this.consented,
    required this.signedIn,
    this.hasLimit,
  });

  /// Config fetched and session restored.
  final bool launched;
  final bool updateRequired;
  final bool maintenance;
  final bool consented;
  final bool signedIn;

  /// Null while unknown (the dashboard hasn't loaded): don't redirect.
  final bool? hasLimit;
}

/// The guards in brief §5.3, in order. Returns where to go instead of
/// [location], or null to stay. Gates use `go()` (the router's redirect
/// replaces the stack), so back can't step past them.
String? guardRedirect(
  GuardInput s,
  Uri location, {
  Set<String> limitOnly = Routes.limitOnly,
}) {
  final path = location.path;
  final from = _from(location);

  // Launching: hold on the splash, remembering where we were going.
  if (!s.launched) {
    if (path == Routes.splash) return null;
    return _with(Routes.splash, path == '/' ? null : location.toString());
  }

  // The dev-only widget gallery sits outside every gate.
  if (path == Routes.gallery) return null;

  // 1. Update required.
  if (s.updateRequired) {
    return path == Routes.update ? null : Routes.update;
  }

  // 2. Maintenance.
  if (s.maintenance) {
    return path == Routes.maintenance
        ? null
        : _with(Routes.maintenance, _target(location, from));
  }

  // 3. No consent: First run, once, before sign-in.
  if (!s.consented) {
    return path == Routes.firstRun
        ? null
        : _with(Routes.firstRun, _target(location, from));
  }

  final isPublic = Routes.public.contains(path);

  // 4. No token: Sign in, remembering the route.
  if (!s.signedIn) {
    if (isPublic && !Routes.gates.contains(path) && path != Routes.splash) {
      return null;
    }
    if (path == Routes.splash || Routes.gates.contains(path) || path == '/') {
      // Leaving a gate or the splash: carry its `from` on to Sign in.
      return from == null ? Routes.welcome : _with(Routes.login, from);
    }
    return _with(Routes.login, location.toString());
  }

  // Signed in: launch and auth screens are behind us.
  if (isPublic || path == '/') {
    return _safeFrom(from) ?? Routes.home;
  }

  // 6. Limit-only routes without a limit.
  if (s.hasLimit == false && limitOnly.contains(path)) return Routes.home;

  return null;
}

String? _from(Uri location) {
  final f = location.queryParameters['from'];
  return f == null || f.isEmpty ? null : f;
}

/// Where a gate should continue to once it clears.
String? _target(Uri location, String? from) {
  final path = location.path;
  if (path == Routes.splash || Routes.gates.contains(path) || path == '/') {
    return from;
  }
  return location.toString();
}

/// Only in-app paths, and never back into launch or auth (no loops).
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.parse(from).path;
  if (Routes.public.contains(path)) return null;
  return from;
}

String _with(String path, String? from) => from == null
    ? path
    : Uri(path: path, queryParameters: {'from': from}).toString();
