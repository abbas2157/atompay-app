// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// `GET /me` (handbook §8.7).
@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String name,
    required String shortName,
    required String? email,
    @Default(false) bool emailVerified,
    String? phone,
    String? phoneFormatted,
    String? memberSince,
    @JsonKey(unknownEnumValue: KycStatus.unknown)
    @Default(KycStatus.notStarted)
    KycStatus kycStatus,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

/// The body of login, sign-up verify and password reset.
@freezed
abstract class AuthResult with _$AuthResult {
  const factory AuthResult({
    required String token,
    required DateTime expiresAt,
    required User user,
  }) = _AuthResult;

  factory AuthResult.fromJson(Map<String, dynamic> json) =>
      _$AuthResultFromJson(json);
}

enum CodeChannel {
  email,
  whatsapp,

  /// Anything newer: show the generic wording.
  unknown,
}

/// `202` from `/auth/register` or `/auth/password/forgot`. [id] is the
/// `signup_id` or `request_id`.
@freezed
abstract class CodeChallenge with _$CodeChallenge {
  const factory CodeChallenge({
    required String id,
    required CodeChannel channel,
    required String destination,
    required int expiresIn,
    required int resendIn,
  }) = _CodeChallenge;
}

/// `GET /auth/sessions` item.
@freezed
abstract class DeviceSession with _$DeviceSession {
  const factory DeviceSession({
    required int id,
    required String? deviceName,
    required bool current,
    required DateTime signedInAt,
    required DateTime? lastUsedAt,
    required DateTime expiresAt,
  }) = _DeviceSession;

  factory DeviceSession.fromJson(Map<String, dynamic> json) =>
      _$DeviceSessionFromJson(json);
}
