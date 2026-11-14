// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_models.freezed.dart';
part 'notification_models.g.dart';

/// One inbox item (`docs/api/notifications.md`).
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required int id,
    required String type,
    required String title,
    required DateTime createdAt,
    String? body,
    @Default(false) bool read,
    @Default(NotificationPayload()) NotificationPayload payload,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

/// Where a tap goes: `screen` is `dashboard`, `plan` (+ `orderId`) or
/// `profile`.
@freezed
abstract class NotificationPayload with _$NotificationPayload {
  const factory NotificationPayload({
    String? screen,
    int? orderId,
    int? instalmentId,
  }) = _NotificationPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}

@freezed
abstract class Inbox with _$Inbox {
  const factory Inbox({
    required List<AppNotification> items,
    @Default(0) int unreadCount,
    @Default(1) int currentPage,
    @Default(1) int lastPage,
  }) = _Inbox;
}
