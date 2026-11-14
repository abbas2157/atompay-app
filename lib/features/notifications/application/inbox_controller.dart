import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/notifications/data/notification_models.dart';
import 'package:atompay_mobile/features/notifications/data/notifications_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inbox_controller.g.dart';

/// The notifications inbox. Marking read updates the list in place and
/// refreshes the dashboard's unread count.
@Riverpod(keepAlive: true)
class InboxController extends _$InboxController {
  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<Cached<Inbox>> build() {
    ref.watch(sessionUserIdProvider);
    return ref.watch(notificationsRepositoryProvider).inbox();
  }

  /// Best effort: a failure leaves the item unread for next time.
  Future<void> markRead(int id) async {
    final current = state.value;
    if (current == null || current.fromCache) return;
    final item = current.data.items.where((n) => n.id == id).firstOrNull;
    if (item == null || item.read) return;
    _apply(current, (n) => n.id == id);
    try {
      await _repo.markRead(id);
    } on Object {
      // Shown read for now; the next refresh tells the truth.
    }
    ref.invalidate(dashboardProvider);
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null || current.data.unreadCount == 0) return;
    await _repo.markAllRead();
    _apply(current, (_) => true);
    ref.invalidate(dashboardProvider);
  }

  void _apply(Cached<Inbox> current, bool Function(AppNotification) which) {
    var unread = current.data.unreadCount;
    final items = [
      for (final n in current.data.items)
        if (!n.read && which(n)) n.copyWith(read: true) else n,
    ];
    unread -= current.data.items.where((n) => !n.read && which(n)).length;
    state = AsyncData(
      Cached(current.data.copyWith(items: items, unreadCount: unread)),
    );
  }
}
