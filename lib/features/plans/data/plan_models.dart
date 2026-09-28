// freezed needs the classic `factory Name(...)` form; fields follow the API's
// JSON order rather than required-first.
// ignore_for_file: unnecessary_type_name_in_constructor
// ignore_for_file: always_put_required_named_parameters_first

import 'package:atompay_mobile/core/models/instalment.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_models.freezed.dart';
part 'plan_models.g.dart';

/// One AtomShop order paid in instalments (handbook §8.10b). The detail
/// endpoint adds [instalments].
@freezed
abstract class Plan with _$Plan {
  const factory Plan({
    required PlanOrder order,

    /// Null when the product was removed from AtomShop.
    PlanProduct? product,

    /// `on_track` · `late` · `completed`.
    required String state,
    required PlanProgress progress,
    Instalment? nextDue,
    @Default([]) List<Instalment> instalments,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

@freezed
abstract class PlanOrder with _$PlanOrder {
  const factory PlanOrder({
    required int id,
    required String reference,
    required String status,
    required String statusLabel,
    DateTime? orderedAt,
    @Default(0) int totalPrice,
    @Default(0) int advance,
    @Default(0) int financed,
    int? tenure,
  }) = _PlanOrder;

  factory PlanOrder.fromJson(Map<String, dynamic> json) =>
      _$PlanOrderFromJson(json);
}

@freezed
abstract class PlanProduct with _$PlanProduct {
  const factory PlanProduct({
    required int id,
    required String title,

    /// Public AtomShop image: no auth header, fine to cache.
    String? pictureUrl,
    String? shopUrl,
  }) = _PlanProduct;

  factory PlanProduct.fromJson(Map<String, dynamic> json) =>
      _$PlanProductFromJson(json);
}

@freezed
abstract class PlanProgress with _$PlanProgress {
  const factory PlanProgress({
    @Default(0) int paidCount,
    @Default(0) int totalCount,
    @Default(0) int paidAmount,
    @Default(0) int totalAmount,
    @Default(0) int remainingAmount,
    @Default(0) int percent,
  }) = _PlanProgress;

  factory PlanProgress.fromJson(Map<String, dynamic> json) =>
      _$PlanProgressFromJson(json);
}
