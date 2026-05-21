// KAMOS — Public collections providers.
//
// Cursor-paginated AsyncNotifier. `refresh()` resets and pulls the first page;
// `loadMore()` is a no-op when there's nothing left or another fetch is in
// flight.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collection.dart';
import '../repository/public_collections_repository.dart';

class PublicCollectionsState {
  const PublicCollectionsState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<CollectionWithOwner> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  PublicCollectionsState copyWith({
    List<CollectionWithOwner>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => PublicCollectionsState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class PublicCollectionsNotifier extends AsyncNotifier<PublicCollectionsState> {
  @override
  Future<PublicCollectionsState> build() async {
    final page = await ref.read(publicCollectionsRepositoryProvider).list();
    return PublicCollectionsState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(publicCollectionsRepositoryProvider).list();
      return PublicCollectionsState(
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
      final page = await ref
          .read(publicCollectionsRepositoryProvider)
          .list(cursor: current.nextCursor);
      state = AsyncValue.data(
        PublicCollectionsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      // Restore the prior state (no error toast for "load more" failures —
      // the user can scroll again or pull-to-refresh).
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final publicCollectionsProvider =
    AsyncNotifierProvider<PublicCollectionsNotifier, PublicCollectionsState>(
      PublicCollectionsNotifier.new,
    );
