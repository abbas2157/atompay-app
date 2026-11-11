// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_models.freezed.dart';
part 'dashboard_models.g.dart';

/// `GET /dashboard`: the whole Home screen in one call.
@freezed
abstract class Dashboard with _$Dashboard {
  const factory Dashboard({
    required String kycStatus,
    required Limit limit,

    /// Latest application: null (never applied), `pending`, `approved`,
    /// `conditional` or `rejected`.
    String? applicationStatus,
    HomeBanner? banner,
    @Default([]) List<Stage> stages,
    Instalment? nextDue,
    @Default(PlansSummary()) PlansSummary plans,
    @Default(0) int unreadNotifications,
  }) = _Dashboard;

  factory Dashboard.fromJson(Map<String, dynamic> json) =>
      _$DashboardFromJson(json);
}

/// `tone`: `pending` (amber) · `blocked` (coral) · `done` (green).
/// `action`: `apply` · `profile` · `application`, or null.
@freezed
abstract class HomeBanner with _$HomeBanner {
  const factory HomeBanner({
    required String tone,
    required String title,
    String? text,
    String? cta,
    String? action,
  }) = _HomeBanner;

  factory HomeBanner.fromJson(Map<String, dynamic> json) =>
      _$HomeBannerFromJson(json);
}

/// The limit in force. Money fields are 0 when `hasLimit` is false.
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

/// `state`: `done` · `current` · `upcoming` · `blocked`.
@freezed
abstract class Stage with _$Stage {
  const factory Stage({
    required String key,
    required String title,
    required String state,
    String? hint,
  }) = _Stage;

  factory Stage.fromJson(Map<String, dynamic> json) => _$StageFromJson(json);
}

@freezed
abstract class PlansSummary with _$PlansSummary {
  const factory PlansSummary({
    @Default(0) int activeCount,
    @Default(0) int pendingCount,
    @Default(false) bool hasLate,
  }) = _PlansSummary;

  factory PlansSummary.fromJson(Map<String, dynamic> json) =>
      _$PlansSummaryFromJson(json);
}
