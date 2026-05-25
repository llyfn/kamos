// KAMOS — Notification providers (SPEC §5.4).
//
// Three long-lived providers:
//
// * `notificationListProvider` — `AsyncNotifier<NotificationListState>` with
//   cursor pagination, refresh, loadMore, and local mark-read mutations that
//   patch the in-memory list without a full re-fetch. The server-side mark
//   call lives in the repository; this notifier owns the optimistic local
//   patch + invalidation of `unreadCountProvider`.
//
// * `unreadCountProvider` — `AsyncNotifier<int>` feeding the bottom-nav
//   notifications-tab dot. Refreshed on app foreground, on tab focus, and
//   whenever a mark-read mutation succeeds.
//
// On a mark-read, we patch the local list AND invalidate the unread count
// rather than recomputing locally — the server is the source of truth for
// the count (some rows in the user's inbox may not be in the currently
// loaded window).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_toast.dart';
import '../../../core/models/page.dart';
import '../models/notification.dart';
import '../repository/notification_repository.dart';

class NotificationListState {
  const NotificationListState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<KamosNotification> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  NotificationListState copyWith({
    List<KamosNotification>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => NotificationListState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class NotificationListNotifier extends AsyncNotifier<NotificationListState> {
  @override
  Future<NotificationListState> build() async {
    final page = await ref.read(notificationRepositoryProvider).list();
    return NotificationListState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(notificationRepositoryProvider).list();
      return NotificationListState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final Page<KamosNotification> page = await ref
          .read(notificationRepositoryProvider)
          .list(cursor: current.nextCursor);
      state = AsyncValue.data(
        NotificationListState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      // Roll back the loading flag; the user can scroll again to retry.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Marks the named row ids read on the server and, on success, stamps
  /// `readAt` locally for the matching rows so the row tint clears without
  /// a re-fetch. Filters [ids] to the rows currently in the loaded window
  /// that are actually unread — already-read rows would otherwise trigger
  /// a no-op server call. The unread count provider is invalidated so the
  /// tab dot reflects the server-truth count after the mutation lands.
  Future<void> markRead(List<String> ids) async {
    final current = state.asData?.value;
    if (current == null) return;
    final unreadIds = current.items
        .where((n) => n.isUnread && ids.contains(n.id))
        .map((n) => n.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) return;
    try {
      await ref.read(notificationRepositoryProvider).markRead(unreadIds);
    } catch (_) {
      // Mark-read is fire-and-forget; the server is idempotent so the next
      // mark or screen-open will reconcile. Don't surface a toast.
      return;
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final patched = [
      for (final n in current.items)
        unreadIds.contains(n.id) ? n.copyWith(readAt: nowIso) : n,
    ];
    state = AsyncValue.data(current.copyWith(items: patched));
    ref.invalidate(unreadCountProvider);
  }

  /// Marks every unread row read for the authed user. Per
  /// design/notifications_ux.md §3.3 the visual flip is optimistic —
  /// the rows crossfade from unread → read in unison the moment the
  /// button is tapped, and the unread-count provider is invalidated so
  /// the tab dot clears in the same frame. On server failure the
  /// optimistic patch is reverted (rows snap back to unread, count
  /// re-fetches) and a localized toast is emitted via
  /// [apiToastBusProvider] (`notificationsMarkAllError` per §3.3).
  Future<void> markAllRead() async {
    final current = state.asData?.value;
    if (current == null) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final patched = [
      for (final n in current.items)
        n.isUnread ? n.copyWith(readAt: nowIso) : n,
    ];
    state = AsyncValue.data(current.copyWith(items: patched));
    ref.invalidate(unreadCountProvider);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {
      // Snap back to the pre-tap state. Re-invalidate the count so any
      // value the optimistic flip may have driven (e.g. 0 cached for a
      // sub-second window) gets refreshed against server truth.
      state = AsyncValue.data(current);
      ref.invalidate(unreadCountProvider);
      ref
          .read(apiToastBusProvider.notifier)
          .emit(ApiToastKind.notificationsMarkAllFailed);
    }
  }

  /// Local-only patch — removes a row from the loaded window. Used by the
  /// follow_request resolution path: once the user approves or declines a
  /// request the row no longer represents a pending action, so we hide it
  /// from the screen (the underlying notification stays in the inbox and
  /// is marked read separately).
  void removeLocal(String id) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = current.items.where((n) => n.id != id).toList(growable: false);
    state = AsyncValue.data(current.copyWith(items: next));
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, NotificationListState>(
      NotificationListNotifier.new,
    );

class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    try {
      return await ref.read(notificationRepositoryProvider).unreadCount();
    } catch (_) {
      // The unread count drives a passive UI element (the bottom-tab dot).
      // A transient network failure should never crash the shell — fall
      // back to 0 and let the next refresh recover.
      return 0;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).unreadCount(),
    );
  }
}

final unreadCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
