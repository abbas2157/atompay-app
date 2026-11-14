import 'package:atompay_mobile/core/router/routes.dart';

/// Maps `https://atompay.shop/app/...` to an app route (brief §5.5). Returns
/// null for a link the app doesn't know: the caller goes Home and says
/// "That link isn't available". Links carry ids only, never a token or
/// personal data.
String? routeForLink(Uri link) {
  final segs = link.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty || segs.first != 'app') return null;
  final rest = segs.sublist(1);
  int? id(String s) => int.tryParse(s);

  return switch (rest) {
    [] => Routes.home,
    ['orders', final o] when id(o) != null => Routes.plan(id(o)!),
    ['orders', final o, 'kfs'] when id(o) != null => Routes.kfs(id(o)!),
    ['apply'] => Routes.applicationStep(1),
    ['application'] => Routes.applicationStatus,
    ['notifications'] => Routes.notifications,
    ['ask'] => Routes.atom,
    ['account'] => Routes.account,
    _ => null,
  };
}

/// Maps a push's `data` (or an inbox item's `payload`) to a route: the
/// same table as links. Push values are strings, inbox ids are numbers.
String routeForPush(Map<String, Object?> data) {
  final orderId = int.tryParse('${data['order_id'] ?? ''}');
  return switch (data['screen']) {
    'plan' when orderId != null => Routes.plan(orderId),
    'plan' => Routes.plans,
    'profile' => Routes.account,
    _ => Routes.home,
  };
}
