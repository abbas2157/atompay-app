import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/features/notifications/data/notification_models.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_repository.g.dart';

/// The inbox (`docs/api/notifications.md`).
class NotificationsRepository {
  new(this._dio, this._cache);

  final Dio _dio;
  final ResponseCache _cache;

  /// One page, newest first. Page 1 is cached for offline.
  Future<Cached<Inbox>> inbox({int page = 1}) {
    Future<Object?> load() => guard(
      () async => (await _dio.get<dynamic>(
        '/notifications',
        queryParameters: {'page': page},
      )).data,
    );
    Inbox parse(Object? body) {
      final meta = body is Map && body['meta'] is Map
          ? (body['meta'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      return Inbox(
        items: listIn(body).map(AppNotification.fromJson).toList(),
        unreadCount: (meta['unread_count'] as int?) ?? 0,
        currentPage: (meta['current_page'] as int?) ?? page,
        lastPage: (meta['last_page'] as int?) ?? page,
      );
    }

    if (page != 1) return load().then((b) => Cached(parse(b)));
    return _cache.fetch(key: 'notifications', load: load, parse: parse);
  }

  Future<void> markRead(int id) => guard(() async {
    await _dio.post<dynamic>('/notifications/$id/read');
  });

  Future<void> markAllRead() => guard(() async {
    await _dio.post<dynamic>('/notifications/read-all');
  });
}

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) =>
    NotificationsRepository(
      ref.watch(dioProvider),
      ref.watch(responseCacheProvider),
    );
