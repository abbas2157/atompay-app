import 'package:json_annotation/json_annotation.dart';

/// `kyc_status` on `/me` and `status` on `/profile` (handbook §8.7).
@JsonEnum(fieldRename: FieldRename.snake)
enum KycStatus {
  notStarted,
  pending,
  verified,
  rejected,

  /// A value added on the server after this build. Render neutrally.
  unknown,
}
