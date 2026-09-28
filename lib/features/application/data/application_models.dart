// freezed needs the classic `factory Name(...)` form; fields follow the API's
// JSON order rather than required-first.
// ignore_for_file: unnecessary_type_name_in_constructor
// ignore_for_file: always_put_required_named_parameters_first

import 'package:freezed_annotation/freezed_annotation.dart';

part 'application_models.freezed.dart';
part 'application_models.g.dart';

/// `GET /application` (handbook §8.9b).
@freezed
abstract class ApplicationOverview with _$ApplicationOverview {
  const factory ApplicationOverview({
    @Default(false) bool canApply,

    /// `profile` when [canApply] is false.
    String? requires,

    /// Pre-fills the form.
    Assessment? latest,

    /// The limit in force; differs from [latest] while a re-application is
    /// pending.
    Assessment? active,
  }) = _ApplicationOverview;

  factory ApplicationOverview.fromJson(Map<String, dynamic> json) =>
      _$ApplicationOverviewFromJson(json);
}

/// One income assessment. Every submission creates a new one.
@freezed
abstract class Assessment with _$Assessment {
  const factory Assessment({
    required int id,

    /// `pending` · `approved` · `conditional` · `rejected`.
    required String status,
    required String statusLabel,
    @Default(false) bool isUsable,
    required String employmentStatus,
    required String employmentStatusLabel,
    String? employerName,
    required String incomeSource,
    required String incomeSourceLabel,
    required int monthlyIncome,
    @Default(0) int existingInstalments,
    @Default(0) int monthlyExpenses,

    /// Can be negative.
    @Default(0) int disposableIncome,

    /// Null until staff decide.
    int? approvedLimit,
    int? maxInstalment,
    int? approvedTenure,

    /// Written by staff for the customer.
    String? notes,
    DateTime? submittedAt,
    DateTime? decidedAt,
  }) = _Assessment;

  factory Assessment.fromJson(Map<String, dynamic> json) =>
      _$AssessmentFromJson(json);
}

/// `GET /options` (handbook §8.12). Send `value`, show `label`.
@freezed
abstract class FormOptions with _$FormOptions {
  const factory FormOptions({
    @Default([]) List<EmploymentOption> employmentStatuses,
    @Default([]) List<Option> incomeSources,
  }) = _FormOptions;

  factory FormOptions.fromJson(Map<String, dynamic> json) =>
      _$FormOptionsFromJson(json);
}

@freezed
abstract class EmploymentOption with _$EmploymentOption {
  const factory EmploymentOption({
    required String value,
    required String label,
    @Default(false) bool hasEmployer,
  }) = _EmploymentOption;

  factory EmploymentOption.fromJson(Map<String, dynamic> json) =>
      _$EmploymentOptionFromJson(json);
}

@freezed
abstract class Option with _$Option {
  const factory Option({required String value, required String label}) =
      _Option;

  factory Option.fromJson(Map<String, dynamic> json) => _$OptionFromJson(json);
}

/// `POST /estimate`. Always labelled "estimate".
@freezed
abstract class Estimate with _$Estimate {
  const factory Estimate({
    required int monthlyIncome,
    required int estimatedLimit,
    required int estimatedMaxInstalment,
  }) = _Estimate;

  factory Estimate.fromJson(Map<String, dynamic> json) =>
      _$EstimateFromJson(json);
}

/// What `POST /application` sends.
class ApplicationInput {
  const new({
    required this.employmentStatus,
    required this.incomeSource,
    required this.monthlyIncome,
    this.employerName,
    this.existingInstalments,
    this.monthlyExpenses,
  });

  final String employmentStatus;
  final String? employerName;
  final String incomeSource;
  final int monthlyIncome;
  final int? existingInstalments;
  final int? monthlyExpenses;

  Map<String, dynamic> toJson() => {
    'employment_status': employmentStatus,
    if (employerName != null && employerName!.trim().isNotEmpty)
      'employer_name': employerName!.trim(),
    'income_source': incomeSource,
    'monthly_income': monthlyIncome,
    'existing_instalments': existingInstalments ?? 0,
    'monthly_expenses': monthlyExpenses ?? 0,
  };
}
