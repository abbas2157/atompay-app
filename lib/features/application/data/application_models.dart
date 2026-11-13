// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:atompay_mobile/features/application/data/kyc_status.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'application_models.freezed.dart';
part 'application_models.g.dart';

/// `GET /profile`: identity details (KYC section 1). Before the first
/// submission it's a draft pre-filled from AtomShop, `status:
/// not_started`.
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    /// `not_started` · `pending` · `verified` · `rejected`.
    @Default('not_started') String status,
    String? fullName,
    String? cnic,
    String? cnicFormatted,
    String? mobile,
    String? mobileFormatted,

    /// `YYYY-MM-DD`.
    String? dateOfBirth,
    String? residentialAddress,
    Place? city,

    /// Brief §7.2.
    Place? area,
    @Default({}) Map<String, DocumentInfo> documents,
    @Default(false) bool addressVerified,
    DateTime? verifiedAt,
    DateTime? submittedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

extension ProfileX on Profile {
  KycStatus get kyc => KycStatus.parse(status);
  bool get submitted => kyc != KycStatus.notStarted;
  bool uploaded(String doc) => documents[doc]?.uploaded ?? false;
}

@freezed
abstract class DocumentInfo with _$DocumentInfo {
  const factory DocumentInfo({@Default(false) bool uploaded, String? url}) =
      _DocumentInfo;

  factory DocumentInfo.fromJson(Map<String, dynamic> json) =>
      _$DocumentInfoFromJson(json);
}

/// One income application (KYC section 3). The decision fields stay null
/// until staff decide.
@freezed
abstract class Assessment with _$Assessment {
  const factory Assessment({
    required int id,

    /// `pending` · `approved` · `conditional` · `rejected`.
    required String status,
    String? statusLabel,
    @Default(false) bool isUsable,
    String? employmentStatus,
    String? employmentStatusLabel,
    String? employerName,
    String? incomeSource,
    String? incomeSourceLabel,
    @Default(0) int monthlyIncome,
    @Default(0) int existingInstalments,
    @Default(0) int monthlyExpenses,
    int? disposableIncome,
    int? approvedLimit,
    int? maxInstalment,
    int? approvedTenure,

    /// The reviewer's note, shown exactly as written.
    String? notes,
    DateTime? submittedAt,
    DateTime? decidedAt,
  }) = _Assessment;

  factory Assessment.fromJson(Map<String, dynamic> json) =>
      _$AssessmentFromJson(json);
}

extension AssessmentX on Assessment {
  AssessmentStatus get decision => AssessmentStatus.parse(status);
}

/// Which board an application is shown on.
enum ApplicationView {
  /// The KYC and verification board (or, in the history, the decision).
  standard,

  /// A pending limit review while another limit is in force.
  review,

  /// Not approved.
  rejected,
}

/// The one rule for picking [ApplicationView]. On the status hub a
/// rejected *review* leaves the limit in force, so the hub stays on the
/// KYC board; the history ([inHistory]) shows every rejection as such.
ApplicationView applicationView(
  Assessment? a, {
  Assessment? active,
  bool inHistory = false,
}) {
  if (a == null) return ApplicationView.standard;
  return switch (a.decision) {
    AssessmentStatus.pending when active != null && active.id != a.id =>
      ApplicationView.review,
    AssessmentStatus.rejected when inHistory || active == null =>
      ApplicationView.rejected,
    _ => ApplicationView.standard,
  };
}

/// `GET /application`.
@freezed
abstract class ApplicationInfo with _$ApplicationInfo {
  const factory ApplicationInfo({
    @Default(false) bool canApply,

    /// `profile` when the profile must come first.
    String? requires,
    Assessment? latest,

    /// The limit in force; can differ from [latest] during a review.
    Assessment? active,
  }) = _ApplicationInfo;

  factory ApplicationInfo.fromJson(Map<String, dynamic> json) =>
      _$ApplicationInfoFromJson(json);
}

/// `POST /estimate`: a preview from income alone. Always labelled as an
/// estimate.
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
