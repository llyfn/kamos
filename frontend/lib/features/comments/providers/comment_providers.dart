// KAMOS — Comment providers.
//
// `commentsProvider` is a family-keyed `AsyncNotifierProvider` keyed on the
// check-in id. The state is `CommentsState` (items + cursor + has-more +
// load-more flag). The server returns comments in DESC order (newest first),
// so:
//   * `post` awaits the server's 201, then PREPENDS the persisted row to the
//     head of the list (newest at top). This is pessimistic — the user sees the
//     composer's spinner while the request is in flight and only sees the new
//     comment after the server confirms it. No tentative row is rendered.
//   * `deleteOwn` is optimistic — the row is removed locally before the request
//     and re-inserted at its original index if the server rejects it.
//   * `loadMore` appends older comments to the tail using the keyset cursor.
// On post or delete failure the state is restored and the exception is
// rethrown so callers can surface a toast.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment.dart';
import '../repository/comment_repository.dart';

class CommentsState {
  const CommentsState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<Comment> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  CommentsState copyWith({
    List<Comment>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => CommentsState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class CommentsNotifier extends AsyncNotifier<CommentsState> {
  CommentsNotifier(this.checkInId);
  final String checkInId;

  @override
  Future<CommentsState> build() async {
    final page = await ref.read(commentRepositoryProvider).list(checkInId);
    return CommentsState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(commentRepositoryProvider).list(checkInId);
      return CommentsState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    });
  }

  /// Pages the next batch of OLDER comments using the keyset cursor. No-op if
  /// already loading, if there's nothing left, or if the initial load hasn't
  /// landed yet. On failure the prior state is restored without a toast — the
  /// user can retry by scrolling / tapping again.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(commentRepositoryProvider)
          .list(checkInId, cursor: current.nextCursor);
      state = AsyncValue.data(
        CommentsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Posts a comment pessimistically — awaits the server's 201 with the
  /// persisted row, then PREPENDS that row to the local list (head = newest)
  /// to match the server's DESC ordering. The UI shows the composer spinner
  /// for the duration of the request; no tentative row is rendered. On
  /// failure the state is unchanged and the exception is rethrown so the UI
  /// can surface a toast.
  Future<Comment> post(String body) async {
    final repo = ref.read(commentRepositoryProvider);
    final current = state.asData?.value ?? const CommentsState();
    final created = await repo.create(checkInId: checkInId, body: body);
    state = AsyncValue.data(
      current.copyWith(items: [created, ...current.items]),
    );
    return created;
  }

  /// Pessimistic body-only edit. Awaits the server's 200 with the updated
  /// row, then replaces the local entry in place so the body + `editedAt`
  /// stay in sync. On failure the state is unchanged and the exception is
  /// rethrown so the UI can surface a toast.
  Future<Comment> edit({
    required String commentId,
    required String body,
  }) async {
    final repo = ref.read(commentRepositoryProvider);
    final current = state.asData?.value ?? const CommentsState();
    final idx = current.items.indexWhere((c) => c.id == commentId);
    final updated = await repo.edit(commentId: commentId, body: body);
    if (idx == -1) return updated;
    final next = [...current.items];
    next[idx] = updated;
    state = AsyncValue.data(current.copyWith(items: next));
    return updated;
  }

  /// Optimistically removes the comment locally, then asks the server. On
  /// failure the comment is restored at its original index and the exception
  /// is rethrown so the UI can surface a toast.
  Future<void> deleteOwn(String commentId) async {
    final current = state.asData?.value ?? const CommentsState();
    final idx = current.items.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    final removed = current.items[idx];
    final next = [...current.items]..removeAt(idx);
    state = AsyncValue.data(current.copyWith(items: next));
    try {
      await ref.read(commentRepositoryProvider).deleteOwn(commentId);
    } catch (_) {
      final latest = state.asData?.value ?? current;
      final reverted = [...latest.items]..insert(idx, removed);
      state = AsyncValue.data(latest.copyWith(items: reverted));
      rethrow;
    }
  }
}

final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, CommentsState, String>(
      CommentsNotifier.new,
    );
