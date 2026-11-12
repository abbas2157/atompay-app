import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'products_repository.g.dart';

/// AtomPay-eligible products (brief §7.2). Auth optional: signed in, each
/// product says whether it fits the limit.
class ProductsRepository {
  new(this._dio);

  final Dio _dio;

  Future<ProductPage> products({
    String? category,
    String? query,
    bool withinLimit = false,
    int page = 1,
  }) => guard(() async {
    final r = await _dio.get<dynamic>(
      '/products',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (withinLimit) 'within_limit': 1,
        'page': page,
      },
    );
    final body = r.data;
    final meta = body is Map && body['meta'] is Map
        ? (body['meta'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final items = listOf(r).map(Product.fromJson).toList();
    return ProductPage(
      items: items,
      currentPage: (meta['current_page'] as int?) ?? page,
      lastPage: (meta['last_page'] as int?) ?? page,
      total: (meta['total'] as int?) ?? items.length,
    );
  });

  Future<List<ProductCategory>> categories() => guard(() async {
    final r = await _dio.get<dynamic>('/products/categories');
    return listOf(r).map(ProductCategory.fromJson).toList();
  });

  /// The 3-month plan for a price. Public; throttled 60/min.
  Future<PlanPreview> planPreview(int price) => guard(() async {
    final r = await _dio.get<dynamic>(
      '/plan-preview',
      queryParameters: {'price': price},
    );
    return PlanPreview.fromJson(dataOf(r));
  });

  /// The Key Fact Statement for buying [productId] now: no order number,
  /// no dates. 409 (Conflict, with a code) when the customer can't order it.
  Future<Kfs> kfs(int productId) => guard(() async {
    final r = await _dio.get<dynamic>('/products/$productId/kfs');
    return Kfs.fromJson(dataOf(r));
  });

  /// Atomshop places the order. [kfsAmount] is the statement's
  /// `amount_financed`; a changed price comes back as a 422 on `order`.
  /// Never retried by itself: a timeout may still have placed it.
  Future<PlacedOrder> placeOrder({
    required int productId,
    required int kfsAmount,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/orders',
      data: {
        'product_id': productId,
        'kfs_amount': kfsAmount,
        'accept_kfs': true,
      },
      // Atomshop places it while we wait; the server allows it 60 s.
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    return PlacedOrder.fromJson(dataOf(r));
  });

  /// 404 when the product isn't eligible.
  Future<Product> product(int id) => guard(() async {
    final r = await _dio.get<dynamic>('/products/$id');
    return Product.fromJson(dataOf(r));
  });
}

@Riverpod(keepAlive: true)
ProductsRepository productsRepository(Ref ref) =>
    ProductsRepository(ref.watch(dioProvider));
