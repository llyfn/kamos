// KAMOS — Beverage list + detail providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/beverage.dart';
import '../../../core/models/collection.dart';
import '../../collections/repository/collection_repository.dart';
import '../repository/beverage_repository.dart';

final beverageDetailProvider = FutureProvider.autoDispose
    .family<BeverageDetail, String>((ref, id) async {
      return ref.read(beverageRepositoryProvider).get(id);
    });

/// Resolved state for the beverage-detail "Add to list" bottom sheet.
/// Holds the signed-in user's collections plus the set of collection ids
/// that already contain the beverage. Consumed by
/// [myCollectionsForBeverageProvider].
class MyCollectionsState {
  const MyCollectionsState({required this.all, required this.memberIds});
  final List<Collection> all;
  final Set<String> memberIds;
}

/// Fetches the signed-in user's collections together with which of them
/// already contain the given beverage. The bottom sheet rebuilds its
/// checkbox state from this provider; invalidate it after a successful
/// add/remove so the next open reflects the latest membership.
final myCollectionsForBeverageProvider =
    FutureProvider.family.autoDispose<MyCollectionsState, String>((
      ref,
      beverageId,
    ) async {
      final repo = ref.read(collectionRepositoryProvider);
      final result = await repo.listMineWithMembership(beverageId);
      return MyCollectionsState(
        all: result.all,
        memberIds: result.memberIds,
      );
    });

class BeverageListState {
  const BeverageListState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.category,
    this.query = '',
  });

  final List<Beverage> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? category;
  final String query;

  BeverageListState copyWith({
    List<Beverage>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? category,
    String? query,
    bool clearCategory = false,
    bool clearError = false,
  }) => BeverageListState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    category: clearCategory ? null : (category ?? this.category),
    query: query ?? this.query,
  );
}

class BeverageListNotifier extends Notifier<BeverageListState> {
  @override
  BeverageListState build() => const BeverageListState();

  Future<void> setCategory(String? category) async {
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
      query: state.query,
    );
    await refresh();
  }

  Future<void> setQuery(String q) async {
    state = state.copyWith(query: q);
    await refresh();
  }

  Future<void> refresh() async {
    // Keep existing items + flip isLoading. The Discover screen uses
    // `state.isLoading && state.items.isEmpty` as the cold-start signal —
    // wiping items here would briefly trip that and flash the LogoLoader to
    // a user who was just pulling to refresh or changing query filters.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(beverageRepositoryProvider)
          .list(
            q: state.query.isEmpty ? null : state.query,
            category: state.category,
          );
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(beverageRepositoryProvider)
          .list(
            q: state.query.isEmpty ? null : state.query,
            category: state.category,
            cursor: state.nextCursor,
          );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final beverageListProvider =
    NotifierProvider<BeverageListNotifier, BeverageListState>(
      BeverageListNotifier.new,
    );
