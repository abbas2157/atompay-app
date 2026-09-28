// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_models.freezed.dart';
part 'notification_models.g.dart';

/// One inbox item (handbook §8.11).
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required int id,
    required String type,
    required String title,
    required DateTime createdAt,
    @Default('') String body,

    /// Same keys as a push's `data`: `screen`, `order_id`, … (ids are
    /// numbers here, strings in a push).
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    @Default(false) bool read,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
