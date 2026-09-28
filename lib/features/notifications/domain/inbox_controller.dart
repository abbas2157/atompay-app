import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/features/dashboard/domain/dashboard_controller.dart';
import 'package:atompay_mobile/features/notifications/data/notification_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class Inbox {
  const new({
    this.items = const [],
    this.nextPage,
    this.unread = 0,
    this.loadingMore = false,
  });

  final List<AppNotification> items;

  /// Null when the last page is loaded.
  final int? nextPage;
  final int unread;
  final bool loadingMore;

  Inbox copyWith({
    List<AppNotification>? items,
    int? Function()? nextPage,
    int? unread,
    bool? loadingMore,
  }) => Inbox(
    items: items ?? this.items,
    nextPage: nextPage == null ? this.nextPage : nextPage(),
    unread: unread ?? this.unread,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final inboxProvider = AsyncNotifierProvider.autoDispose<InboxController, Inbox>(
  InboxController.new,
);

/// `GET /notifications` (20 per page, infinite scroll), read, read-all.
class InboxController extends AsyncNotifier<Inbox> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<Inbox> build() async {
    final page = await _page(1);
    return Inbox(items: page.items, nextPage: page.next, unread: page.unread);
  }

  Future<({List<AppNotification> items, int? next, int unread})> _page(
    int number,
  ) async {
    final body = await _api.getPage('/notifications', query: {'page': number});
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final links = (body['links'] as Map?)?.cast<String, dynamic>() ?? const {};
    final current = (meta['current_page'] as num?)?.toInt() ?? number;
    return (
      items: [
        for (final n in (body['data'] as List?) ?? const [])
          AppNotification.fromJson((n as Map).cast<String, dynamic>()),
      ],
      // Follow `links.next`; it's null on the last page.
      next: links['next'] == null ? null : current + 1,
      unread: (meta['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> loadMore() async {
    final inbox = state.value;
    final next = inbox?.nextPage;
    if (inbox == null || next == null || inbox.loadingMore) return;
    state = AsyncData(inbox.copyWith(loadingMore: true));
    try {
      final page = await _page(next);
      if (!ref.mounted) return;
      final seen = {for (final n in inbox.items) n.id};
      state = AsyncData(
        inbox.copyWith(
          items: [
            ...inbox.items,
            ...page.items.where((n) => !seen.contains(n.id)),
          ],
          nextPage: () => page.next,
          unread: page.unread,
          loadingMore: false,
        ),
      );
    } on ApiException {
      if (ref.mounted) state = AsyncData(inbox.copyWith(loadingMore: false));
    }
  }

  /// Optimistic; the server is told in the background.
  Future<void> markRead(AppNotification n) async {
    final inbox = state.value;
    if (inbox == null || n.read) return;
    state = AsyncData(
      inbox.copyWith(
        items: [
          for (final item in inbox.items)
            if (item.id == n.id) item.copyWith(read: true) else item,
        ],
        unread: (inbox.unread - 1).clamp(0, inbox.unread),
      ),
    );
    try {
      await _api.post('/notifications/${n.id}/read');
    } on ApiException {
      // The next refresh shows the truth.
    }
    if (ref.mounted) ref.invalidate(dashboardProvider);
  }

  Future<void> markAllRead() async {
    final inbox = state.value;
    if (inbox == null) return;
    state = AsyncData(
      inbox.copyWith(
        items: [for (final n in inbox.items) n.copyWith(read: true)],
        unread: 0,
      ),
    );
    try {
      await _api.post('/notifications/read-all');
    } on ApiException {
      if (ref.mounted) ref.invalidateSelf();
    }
    if (ref.mounted) ref.invalidate(dashboardProvider);
  }
}

/// Where a notification (inbox or push) opens: `payload.screen`
/// (handbook §8.11). Unknown values go Home.
String routeForPayload(Map<String, dynamic> payload) {
  final orderId = int.tryParse('${payload['order_id']}');
  return switch (payload['screen']) {
    'plan' when orderId != null => Routes.plan(orderId),
    'profile' => Routes.profile,
    _ => Routes.home,
  };
}
