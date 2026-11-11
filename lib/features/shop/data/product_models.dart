// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_models.freezed.dart';
part 'product_models.g.dart';

/// An AtomPay-eligible product (brief §7.2, `GET /products`). Every figure
/// comes from the server.
@freezed
abstract class Product with _$Product {
  const factory Product({
    required int id,
    required String title,
    required int price,
    required int monthly,
    required int lastMonthly,
    required String url,
    String? brand,
    ProductCategory? category,
    String? imageUrl,

    /// Only when signed in; null otherwise.
    bool? withinLimit,

    /// Only on `GET /products/{id}`.
    String? description,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

@freezed
abstract class ProductCategory with _$ProductCategory {
  const factory ProductCategory({
    required int id,
    required String title,
    int? count,
  }) = _ProductCategory;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      _$ProductCategoryFromJson(json);
}

@freezed
abstract class ProductPage with _$ProductPage {
  const factory ProductPage({
    required List<Product> items,
    @Default(1) int currentPage,
    @Default(1) int lastPage,
    @Default(0) int total,
  }) = _ProductPage;
}

/// `GET /plan-preview?price=` (brief §7.2): the one AtomPay plan for a
/// price. Every figure is the server's.
@freezed
abstract class PlanPreview with _$PlanPreview {
  const factory PlanPreview({
    required int price,
    required List<int> instalments,
    required int total,
    @Default(0) int advance,
    @Default(0) int markup,
    @Default(3) int months,
    @Default(3) int processingFeePercent,
    @Default(0) int processingFee,

    /// Only when signed in; null otherwise.
    bool? fitsLimit,
  }) = _PlanPreview;

  factory PlanPreview.fromJson(Map<String, dynamic> json) =>
      _$PlanPreviewFromJson(json);
}
