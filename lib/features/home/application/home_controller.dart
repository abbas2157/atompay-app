import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/data/dashboard_models.dart';
import 'package:atompay_mobile/features/home/data/dashboard_repository.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/data/plans_repository.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:atompay_mobile/features/shop/data/products_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

/// `GET /dashboard` for the signed-in customer. Signing out (a new user
/// id) drops it. A failed refresh keeps the last data on screen.
@Riverpod(keepAlive: true)
Future<Cached<Dashboard>> dashboard(Ref ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(dashboardRepositoryProvider).dashboard();
}

/// Whether a limit is in force; null until the dashboard has loaded. Feeds
/// the router's limit-only guard.
@Riverpod(keepAlive: true)
bool? dashboardHasLimit(Ref ref) =>
    ref.watch(dashboardProvider).value?.data.limit.hasLimit;

/// Every order, for the next-payment card's three-month bar and Orders.
@Riverpod(keepAlive: true)
Future<Cached<List<Plan>>> plans(Ref ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(plansRepositoryProvider).plans();
}

/// "Within your limit" on Home: the first few products that fit.
@riverpod
Future<List<Product>> productsWithinLimit(Ref ref) async {
  ref.watch(sessionUserIdProvider);
  final page = await ref
      .watch(productsRepositoryProvider)
      .products(withinLimit: true);
  return page.items;
}
