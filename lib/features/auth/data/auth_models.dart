// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:atompay_mobile/features/application/data/kyc_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// `GET /me`.
@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String name,
    String? shortName,

    /// Null for mobile-only accounts.
    String? email,
    @Default(false) bool emailVerified,
    String? phone,
    String? phoneFormatted,
    String? memberSince,

    /// `not_started` · `pending` · `verified` · `rejected`.
    @Default('not_started') String kycStatus,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  KycStatus get kyc => KycStatus.parse(kycStatus);

  /// "AK" for the avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '' : parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// The body of login, sign-up verify and password reset.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String token,
    required DateTime expiresAt,
    required User user,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}

/// `POST /auth/register` (202) and `/register/resend`, and
/// `POST /auth/password/forgot` (202): a code is on its way.
@freezed
abstract class CodeSent with _$CodeSent {
  const factory CodeSent({
    /// `signup_id` or `request_id`.
    @JsonKey(readValue: _id) required String id,

    /// `email` · `whatsapp`.
    required String channel,

    /// Masked: `0300*****67`.
    required String destination,
    @Default(600) int expiresIn,
    @Default(60) int resendIn,
  }) = _CodeSent;

  factory CodeSent.fromJson(Map<String, dynamic> json) =>
      _$CodeSentFromJson(json);
}

Object? _id(Map<dynamic, dynamic> json, String key) =>
    json['signup_id'] ?? json['request_id'];

/// `GET /auth/sessions`.
@freezed
abstract class DeviceSession with _$DeviceSession {
  const factory DeviceSession({
    required int id,
    required String deviceName,
    @Default(false) bool current,
    DateTime? signedInAt,
    DateTime? lastUsedAt,
    DateTime? expiresAt,
  }) = _DeviceSession;

  factory DeviceSession.fromJson(Map<String, dynamic> json) =>
      _$DeviceSessionFromJson(json);
}
