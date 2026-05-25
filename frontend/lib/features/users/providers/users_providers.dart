// KAMOS — Users providers.
//
// `userSearchProvider(query)` and `otherUserCollectionsProvider(username)` are
// cursor-paginated family-keyed AsyncNotifiers. The search screen debounces
// keystrokes (≈300 ms) before flipping the keying string; each unique key is
// its own notifier so paged state never bleeds between queries.
//
// Riverpod 3 pattern: the notifier subclass takes its family arg in the
// constructor, so the `family<N, R, A>(N.new)` call wires `arg → N(arg)`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collection.dart';
import '../models/public_user.dart';
import '../repository/users_repository.dart';

class _Paged<T> {
  const _Paged({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  _Paged<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => _Paged<T>(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

typedef UserSearchState = _Paged<PublicUser>;

class UserSearchNotifier extends AsyncNotifier<UserSearchState> {
  UserSearchNotifier(this.query);
  final String query;

  @override
  Future<UserSearchState> build() async {
    final page = await ref.read(usersRepositoryProvider).search(q: query);
    return UserSearchState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(usersRepositoryProvider)
          .search(q: query, cursor: current.nextCursor);
      state = AsyncValue.data(
        UserSearchState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      // Restore the prior state (no error toast for "load more" failures —
      // the user can scroll again).
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final userSearchProvider =
    AsyncNotifierProvider.family<UserSearchNotifier, UserSearchState, String>(
      UserSearchNotifier.new,
    );

typedef OtherUserCollectionsState = _Paged<Collection>;

class OtherUserCollectionsNotifier extends AsyncNotifier<OtherUserCollectionsState> {
  OtherUserCollectionsNotifier(this.username);
  final String username;

  @override
  Future<OtherUserCollectionsState> build() async {
    final page = await ref
        .read(usersRepositoryProvider)
        .collections(username);
    return OtherUserCollectionsState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(usersRepositoryProvider)
          .collections(username, cursor: current.nextCursor);
      state = AsyncValue.data(
        OtherUserCollectionsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final otherUserCollectionsProvider =
    AsyncNotifierProvider.family<
      OtherUserCollectionsNotifier,
      OtherUserCollectionsState,
      String
    >(OtherUserCollectionsNotifier.new);
