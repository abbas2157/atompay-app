// freezed needs the classic `factory Name(...)` form; fields follow the API's
// JSON order rather than required-first.
// ignore_for_file: unnecessary_type_name_in_constructor
// ignore_for_file: always_put_required_named_parameters_first

import 'package:atompay_mobile/core/models/instalment.dart';
import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_models.freezed.dart';
part 'dashboard_models.g.dart';

/// `GET /dashboard`: the whole home screen in one call (handbook §8.8).
@freezed
abstract class Dashboard with _$Dashboard {
  const factory Dashboard({
    @JsonKey(unknownEnumValue: KycStatus.unknown)
    @Default(KycStatus.notStarted)
    KycStatus kycStatus,

    /// `null` (never applied) · `pending` · `approved` · `conditional` ·
    /// `rejected`: the latest application.
    String? applicationStatus,
    required DashboardBanner banner,
    required Limit limit,
    @Default([]) List<Stage> stages,
    Instalment? nextDue,
    @Default(PlansSummary()) PlansSummary plans,
    @Default(0) int unreadNotifications,
  }) = _Dashboard;

  factory Dashboard.fromJson(Map<String, dynamic> json) =>
      _$DashboardFromJson(json);
}

@freezed
abstract class DashboardBanner with _$DashboardBanner {
  const factory DashboardBanner({
    /// `pending` · `blocked` · `done`.
    required String tone,
    required String title,
    String? text,
    String? cta,

    /// `apply` · `profile` · `application`.
    String? action,
  }) = _DashboardBanner;

  factory DashboardBanner.fromJson(Map<String, dynamic> json) =>
      _$DashboardBannerFromJson(json);
}

/// The limit **in force**. With `has_limit: false` the money is 0 and
/// `status`/`tenure` are null.
@freezed
abstract class Limit with _$Limit {
  const factory Limit({
    @Default(false) bool hasLimit,
    String? status,
    @Default(0) int approved,
    @Default(0) int used,
    @Default(0) int available,
    @Default(0) int usedPercent,
    @Default(0) int maxInstalment,
    int? tenure,
  }) = _Limit;

  factory Limit.fromJson(Map<String, dynamic> json) => _$LimitFromJson(json);
}

@freezed
abstract class Stage with _$Stage {
  const factory Stage({
    required String key,
    required String title,
    @Default('') String hint,

    /// `done` · `current` · `upcoming` · `blocked`.
    required String state,
  }) = _Stage;

  factory Stage.fromJson(Map<String, dynamic> json) => _$StageFromJson(json);
}

@freezed
abstract class PlansSummary with _$PlansSummary {
  const factory PlansSummary({
    @Default(0) int activeCount,
    @Default(false) bool hasLate,
  }) = _PlansSummary;

  factory PlansSummary.fromJson(Map<String, dynamic> json) =>
      _$PlansSummaryFromJson(json);
}
