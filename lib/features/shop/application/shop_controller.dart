import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:atompay_mobile/features/shop/data/products_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Shop list is showing.
@immutable
class ProductFilter {
  const new({this.category, this.query = '', this.withinLimit = false});

  /// A category id, or null for every category.
  final int? category;
  final String query;
  final bool withinLimit;

  bool get isDefault => category == null && query.isEmpty && !withinLimit;

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.category == category &&
      other.query == query &&
      other.withinLimit == withinLimit;

  @override
  int get hashCode => Object.hash(category, query, withinLimit);
}

/// The Shop tab's filter: kept while the customer moves between tabs.
final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  // A setter keeps very_good_analysis happy.
  // ignore: avoid_setters_without_getters
  set filter(ProductFilter f) => state = f;
}

final productCategoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(productsRepositoryProvider).categories();
});

/// Eligible products for a filter, page by page.
final productListProvider =
    AsyncNotifierProvider.family<
      ProductListController,
      ProductPage,
      ProductFilter
    >(ProductListController.new);

class ProductListController extends AsyncNotifier<ProductPage> {
  new(this.filter);

  final ProductFilter filter;
  bool _loadingMore = false;

  ProductsRepository get _repo => ref.read(productsRepositoryProvider);

  @override
  Future<ProductPage> build() {
    ref.watch(sessionUserIdProvider);
    return ref
        .watch(productsRepositoryProvider)
        .products(
          category: filter.category?.toString(),
          query: filter.query,
          withinLimit: filter.withinLimit,
        );
  }

  bool get hasMore {
    final p = state.value;
    return p != null && p.currentPage < p.lastPage;
  }

  /// The next page, appended. A failure keeps what's shown.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _repo.products(
        category: filter.category?.toString(),
        query: filter.query,
        withinLimit: filter.withinLimit,
        page: current.currentPage + 1,
      );
      state = AsyncData(
        next.copyWith(items: [...current.items, ...next.items]),
      );
    } on Object {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
    }
  }
}

final productProvider = FutureProvider.autoDispose.family<Product, int>((
  ref,
  id,
) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(productsRepositoryProvider).product(id);
});

/// `GET /plan-preview` for a price.
final planPreviewProvider = FutureProvider.autoDispose.family<PlanPreview, int>(
  (ref, price) {
    ref.watch(sessionUserIdProvider);
    return ref.watch(productsRepositoryProvider).planPreview(price);
  },
);
