// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_models.freezed.dart';
part 'profile_models.g.dart';

/// `GET /profile` (handbook §8.9). Before the first submission it's a draft
/// pre-filled from AtomShop with `status: not_started`.
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    @JsonKey(unknownEnumValue: KycStatus.unknown)
    @Default(KycStatus.notStarted)
    KycStatus status,
    String? fullName,
    String? cnic,
    String? cnicFormatted,
    String? mobile,
    String? mobileFormatted,
    String? dateOfBirth,
    String? residentialAddress,
    City? city,
    @Default(Documents()) Documents documents,
    @Default(false) bool addressVerified,
    DateTime? verifiedAt,
    DateTime? submittedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

@freezed
abstract class City with _$City {
  const factory City({required int id, required String name}) = _City;

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);
}

@freezed
abstract class Documents with _$Documents {
  const factory Documents({
    @Default(DocumentRef()) DocumentRef cnicFront,
    @Default(DocumentRef()) DocumentRef cnicBack,
    @Default(DocumentRef()) DocumentRef selfie,
  }) = _Documents;

  factory Documents.fromJson(Map<String, dynamic> json) =>
      _$DocumentsFromJson(json);
}

@freezed
abstract class DocumentRef with _$DocumentRef {
  const factory DocumentRef({@Default(false) bool uploaded, String? url}) =
      _DocumentRef;

  factory DocumentRef.fromJson(Map<String, dynamic> json) =>
      _$DocumentRefFromJson(json);
}

enum ProfileDocument {
  cnicFront('cnic_front'),
  cnicBack('cnic_back'),
  selfie('selfie');

  new(this.apiName);

  /// Form field and URL segment.
  final String apiName;

  static ProfileDocument? parse(String value) {
    for (final d in values) {
      if (d.apiName == value) return d;
    }
    return null;
  }
}

extension DocumentsX on Documents {
  DocumentRef of(ProfileDocument d) => switch (d) {
    ProfileDocument.cnicFront => cnicFront,
    ProfileDocument.cnicBack => cnicBack,
    ProfileDocument.selfie => selfie,
  };
}

/// What `POST /profile` sends. Every text field every time.
class ProfileInput {
  const new({
    required this.fullName,
    required this.cnic,
    required this.mobile,
    required this.dateOfBirth,
    required this.residentialAddress,
    this.cityId,
  });

  final String fullName;
  final String cnic;
  final String mobile;

  /// `YYYY-MM-DD`.
  final String dateOfBirth;
  final String residentialAddress;
  final int? cityId;
}
