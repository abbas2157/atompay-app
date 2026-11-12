// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_models.freezed.dart';
part 'plan_models.g.dart';

/// One monthly payment (`docs/api/plans.md`). `state` is `paid`, `late`,
/// `due` (within 14 days) or `upcoming`.
@freezed
abstract class Instalment with _$Instalment {
  const factory Instalment({
    required int id,
    required int orderId,
    required String label,
    required DateTime dueDate,
    required int amount,
    required String state,
    int? paidAmount,
    DateTime? paidOn,

    /// How it was paid ("JazzCash"). Proposed API field.
    String? paidVia,

    /// Only on `next_due` objects.
    String? orderReference,
    String? productTitle,
  }) = _Instalment;

  factory Instalment.fromJson(Map<String, dynamic> json) =>
      _$InstalmentFromJson(json);
}

@freezed
abstract class PlanOrder with _$PlanOrder {
  const factory PlanOrder({
    required int id,
    required String reference,
    required int totalPrice,
    String? status,
    String? statusLabel,
    DateTime? orderedAt,

    /// When AtomShop marked it delivered. Proposed API field.
    DateTime? deliveredAt,
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

/// An order and its plan. `state`: `pending` · `processing` · `on_track` ·
/// `late` · `completed` · `cancelled`.
@freezed
abstract class Plan with _$Plan {
  const factory Plan({
    required PlanOrder order,
    required String state,
    @Default(PlanProgress()) PlanProgress progress,
    PlanProduct? product,
    Instalment? nextDue,

    /// Only on `GET /plans/{order}`.
    @Default([]) List<Instalment> instalments,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

/// `GET /plans/{order}/kfs` (brief §7.2), or `GET /products/{id}/kfs`
/// before an order exists: the Key Fact Statement. Null fields are facts
/// the business hasn't supplied: shown as placeholders.
@freezed
abstract class Kfs with _$Kfs {
  const factory Kfs({
    required int amountFinanced,
    required int months,
    required int totalRepayable,

    /// Null before the order exists (`GET /products/{id}/kfs`).
    String? orderNumber,
    String? product,
    @Default(KfsLender()) KfsLender lender,
    @Default(0) int advance,
    @Default(0) num markupPercent,
    @Default(0) num processingFeePercent,
    @Default(0) int processingFee,
    num? aprPercent,
    @Default([]) List<KfsInstalment> instalments,
    String? latePayment,
    String? earlySettlement,
    String? complaints,
    DateTime? issuedAt,

    /// When the customer accepted these terms at Atomshop checkout. Null
    /// until checkout records it (docs/backend/SERVER_RELEASE_PROMPT.md §8).
    DateTime? acceptedAt,
  }) = _Kfs;

  factory Kfs.fromJson(Map<String, dynamic> json) => _$KfsFromJson(json);
}

@freezed
abstract class KfsLender with _$KfsLender {
  const factory KfsLender({String? name, String? licence, String? address}) =
      _KfsLender;

  factory KfsLender.fromJson(Map<String, dynamic> json) =>
      _$KfsLenderFromJson(json);
}

@freezed
abstract class KfsInstalment with _$KfsInstalment {
  const factory KfsInstalment({
    required int number,
    required int amount,

    /// Null until Atomshop delivers the order and sets the dates.
    DateTime? dueDate,
  }) = _KfsInstalment;

  factory KfsInstalment.fromJson(Map<String, dynamic> json) =>
      _$KfsInstalmentFromJson(json);
}
