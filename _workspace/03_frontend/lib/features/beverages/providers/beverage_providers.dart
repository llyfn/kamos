// KAMOS — Beverage list + detail providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/beverage.dart';
import '../repository/beverage_repository.dart';

final beverageDetailProvider =
    FutureProvider.autoDispose.family<BeverageDetail, String>((ref, id) async {
  return ref.read(beverageRepositoryProvider).get(id);
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
  }) =>
      BeverageListState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error ?? this.error,
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
    state = state.copyWith(
      isLoading: true,
      items: const [],
      nextCursor: null,
      hasMore: true,
      error: null,
    );
    try {
      final page = await ref.read(beverageRepositoryProvider).list(
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
      final page = await ref.read(beverageRepositoryProvider).list(
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
