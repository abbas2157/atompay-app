// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

/// `GET /app-config` (handbook §8.12).
@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(PerPlatform()) PerPlatform minVersion,
    @Default(PerPlatform()) PerPlatform storeUrl,
    @Default('https://atomshop.pk') String shopUrl,
    String? passwordResetUrl,
    // Both stores require the policy inside the app; the default keeps it
    // reachable before the server sends the field (or offline).
    @Default('https://atompay.shop/privacy-policy') String privacyUrl,
    String? termsUrl,
    @Default(Support()) Support support,
    @Default(Features()) Features features,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}

@freezed
abstract class PerPlatform with _$PerPlatform {
  const factory PerPlatform({String? android, String? ios}) = _PerPlatform;

  factory PerPlatform.fromJson(Map<String, dynamic> json) =>
      _$PerPlatformFromJson(json);
}

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
    @Default(['email', 'whatsapp']) List<String> passwordResetChannels,
    @Default(['email', 'whatsapp']) List<String> signupChannels,
  }) = _Features;

  factory Features.fromJson(Map<String, dynamic> json) =>
      _$FeaturesFromJson(json);
}

extension FeaturesX on Features {
  bool get signupByWhatsapp => signupChannels.contains('whatsapp');
  bool get resetByWhatsapp => passwordResetChannels.contains('whatsapp');
}
