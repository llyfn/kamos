// KAMOS — User beverages provider.
//
// AsyncNotifier family keyed by `UserBeveragesArgs`. A change in any
// filter/sort/dir field creates a fresh notifier with a fresh first-page
// fetch (cursor null). `autoDispose` releases the prior notifier so the
// list never reuses a cursor across sort modes.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_beverage.dart';
import '../repository/users_repository.dart';

class UserBeveragesArgs {
  const UserBeveragesArgs({
    required this.username,
    this.categorySlug,
    this.producerId,
    this.minRating,
    this.sort = 'rating',
    this.sortDir,
  });

  final String username;
  final String? categorySlug;
  final String? producerId;
  final double? minRating;
  final String sort;
  final String? sortDir;

  @override
  bool operator ==(Object other) =>
      other is UserBeveragesArgs &&
      other.username == username &&
      other.categorySlug == categorySlug &&
      other.producerId == producerId &&
      other.minRating == minRating &&
      other.sort == sort &&
      other.sortDir == sortDir;

  @override
  int get hashCode => Object.hash(
    username,
    categorySlug,
    producerId,
    minRating,
    sort,
    sortDir,
  );
}

class UserBeveragesState {
  const UserBeveragesState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<UserBeverageRow> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  UserBeveragesState copyWith({
    List<UserBeverageRow>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => UserBeveragesState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class UserBeveragesNotifier
    extends AsyncNotifier<UserBeveragesState> {
  UserBeveragesNotifier(this.args);
  final UserBeveragesArgs args;

  @override
  Future<UserBeveragesState> build() async {
    final page = await ref
        .read(usersRepositoryProvider)
        .getUserBeverages(
          args.username,
          categorySlug: args.categorySlug,
          producerId: args.producerId,
          minRating: args.minRating,
          sort: args.sort,
          sortDir: args.sortDir,
        );
    return UserBeveragesState(
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
          .getUserBeverages(
            args.username,
            cursor: current.nextCursor,
            categorySlug: args.categorySlug,
            producerId: args.producerId,
            minRating: args.minRating,
            sort: args.sort,
            sortDir: args.sortDir,
          );
      state = AsyncValue.data(
        UserBeveragesState(
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

final userBeveragesProvider =
    AsyncNotifierProvider.autoDispose.family<
      UserBeveragesNotifier,
      UserBeveragesState,
      UserBeveragesArgs
    >(UserBeveragesNotifier.new);
