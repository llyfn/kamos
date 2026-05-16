// KAMOS — Comment providers (Phase 6).
//
// `commentsProvider` is a family-keyed `AsyncNotifierProvider` keyed on the
// check-in id. The mutation methods (`post`, `deleteOwn`) update the state
// list optimistically; on failure the original list is restored.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment.dart';
import '../repository/comment_repository.dart';

class CommentsNotifier extends AsyncNotifier<List<Comment>> {
  CommentsNotifier(this.checkInId);
  final String checkInId;

  @override
  Future<List<Comment>> build() {
    return ref.read(commentRepositoryProvider).list(checkInId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(commentRepositoryProvider).list(checkInId),
    );
  }

  /// Posts a comment. Returns the server-side `Comment` (with id + timestamps)
  /// so callers can react if needed. The list is updated by appending — flat
  /// list, oldest first per server contract.
  Future<Comment> post(String body) async {
    final repo = ref.read(commentRepositoryProvider);
    final created = await repo.create(checkInId: checkInId, body: body);
    final current = state.asData?.value ?? const <Comment>[];
    state = AsyncValue.data([...current, created]);
    return created;
  }

  /// Optimistically removes the comment locally, then asks the server. On
  /// failure the comment is restored at its original index and the exception
  /// is rethrown so the UI can surface a toast.
  Future<void> deleteOwn(String commentId) async {
    final current = state.asData?.value ?? const <Comment>[];
    final idx = current.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    final removed = current[idx];
    final next = [...current]..removeAt(idx);
    state = AsyncValue.data(next);
    try {
      await ref.read(commentRepositoryProvider).deleteOwn(commentId);
    } catch (_) {
      final reverted = [...(state.asData?.value ?? const <Comment>[])]
        ..insert(idx, removed);
      state = AsyncValue.data(reverted);
      rethrow;
    }
  }
}

final commentsProvider = AsyncNotifierProvider.family<CommentsNotifier,
    List<Comment>, String>(
  CommentsNotifier.new,
);
