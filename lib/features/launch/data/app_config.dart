// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

/// `GET /app-config`, including the keys brief §7.2 adds (maintenance,
/// apps, features.voice). Missing keys fall back to safe defaults.
@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(PlatformValue()) PlatformValue minVersion,
    @Default(PlatformValue()) PlatformValue storeUrl,
    @Default('https://atomshop.pk') String shopUrl,
    String? passwordResetUrl,
    @Default('https://atompay.shop/privacy-policy') String privacyUrl,

    /// Null until terms are published: hide the link.
    String? termsUrl,
    String? accountDeletionUrl,
    @Default(Support()) Support support,
    @Default(Features()) Features features,
    @Default(Maintenance()) Maintenance maintenance,
    @Default(EcosystemApps()) EcosystemApps apps,
    @Default(Business()) Business business,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}

/// The company behind the instalments, set in Atomshop's admin panel and
/// served in `/app-config.business`. Atomshop sells on instalments itself
/// (no lender, no SECP licence), so nothing here claims one. A null field
/// shows its rose placeholder, so a missing fact is visible.
@freezed
abstract class Business with _$Business {
  const factory Business({
    /// Atomshop's registered company, which offers the instalments.
    String? companyName,
    String? registeredAddress,

    /// Where customer data is stored ("Pakistan").
    String? dataHosting,

    /// Late-payment charges, as customers should read them.
    String? latePayment,

    /// Early-settlement terms.
    String? earlySettlement,

    /// When a complaint gets a reply ("2 working days").
    String? complaintResponseTime,
  }) = _Business;

  factory Business.fromJson(Map<String, dynamic> json) =>
      _$BusinessFromJson(json);
}

@freezed
abstract class PlatformValue with _$PlatformValue {
  const factory PlatformValue({String? android, String? ios}) = _PlatformValue;

  factory PlatformValue.fromJson(Map<String, dynamic> json) =>
      _$PlatformValueFromJson(json);
}

/// Hide any row whose value is null.
@freezed
abstract class Support with _$Support {
  const factory Support({String? phone, String? whatsapp, String? email}) =
      _Support;

  factory Support.fromJson(Map<String, dynamic> json) =>
      _$SupportFromJson(json);
}

@freezed
abstract class Features with _$Features {
  const factory Features({
    @Default(false) bool push,
    @Default(['email']) List<String> passwordResetChannels,
    @Default(['email']) List<String> signupChannels,

    /// Hide the Ask Atom mic when false.
    @Default(true) bool voice,

    /// "Buy with AtomPay" in the app (docs/api/orders.md). Off: the product
    /// page keeps "Buy on Atomshop.pk" only.
    @Default(false) bool inAppOrders,
  }) = _Features;

  factory Features.fromJson(Map<String, dynamic> json) =>
      _$FeaturesFromJson(json);
}

@freezed
abstract class Maintenance with _$Maintenance {
  const factory Maintenance({
    @Default(false) bool active,
    String? message,
    DateTime? until,
  }) = _Maintenance;

  factory Maintenance.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceFromJson(json);
}

/// Store and web links for the four Atom apps. A null store link shows
/// "Android soon" / "iOS soon".
@freezed
abstract class EcosystemApps with _$EcosystemApps {
  const factory EcosystemApps({
    @Default(AppLinks(web: 'https://atomshop.pk')) AppLinks atomshop,
    @Default(AppLinks(web: 'https://atompay.shop')) AppLinks atompay,
    @Default(AppLinks(web: 'https://atomshop.pk/smart-seller'))
    AppLinks atomseller,
    @Default(AppLinks(web: 'https://atomshop.pk/brand-partners'))
    AppLinks atombrand,
  }) = _EcosystemApps;

  factory EcosystemApps.fromJson(Map<String, dynamic> json) =>
      _$EcosystemAppsFromJson(json);
}

@freezed
abstract class AppLinks with _$AppLinks {
  const factory AppLinks({String? android, String? ios, String? web}) =
      _AppLinks;

  factory AppLinks.fromJson(Map<String, dynamic> json) =>
      _$AppLinksFromJson(json);
}

/// `GET /options`: picker values. Send `value`, show `label`.
@freezed
abstract class FormOptions with _$FormOptions {
  const factory FormOptions({
    @Default([]) List<EmploymentOption> employmentStatuses,
    @Default([]) List<LabelledValue> incomeSources,

    /// Brief §7.2. Defaults until the server sends them.
    @Default(defaultComplaintTopics) List<LabelledValue> complaintTopics,
  }) = _FormOptions;

  factory FormOptions.fromJson(Map<String, dynamic> json) =>
      _$FormOptionsFromJson(json);
}

/// The topics brief §7.2 fixes for `POST /complaints`, with the canvas's
/// labels.
const defaultComplaintTopics = [
  LabelledValue(value: 'payment', label: 'A payment'),
  LabelledValue(value: 'order', label: 'An order'),
  LabelledValue(value: 'limit', label: 'My limit or application'),
  LabelledValue(value: 'account', label: 'My account or sign-in'),
  LabelledValue(value: 'other', label: 'Something else'),
];

@freezed
abstract class EmploymentOption with _$EmploymentOption {
  const factory EmploymentOption({
    required String value,
    required String label,

    /// The employer or business name is required, and shown, only then.
    @Default(false) bool hasEmployer,
  }) = _EmploymentOption;

  factory EmploymentOption.fromJson(Map<String, dynamic> json) =>
      _$EmploymentOptionFromJson(json);
}

@freezed
abstract class LabelledValue with _$LabelledValue {
  const factory LabelledValue({required String value, required String label}) =
      _LabelledValue;

  factory LabelledValue.fromJson(Map<String, dynamic> json) =>
      _$LabelledValueFromJson(json);
}

/// `GET /cities`, and brief §7.2's `GET /areas?city_id=` (`title`).
@freezed
abstract class Place with _$Place {
  const factory Place({
    required int id,
    @JsonKey(readValue: _nameOrTitle) required String name,
  }) = _Place;

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);
}

Object? _nameOrTitle(Map<dynamic, dynamic> json, String key) =>
    json['name'] ?? json['title'];
