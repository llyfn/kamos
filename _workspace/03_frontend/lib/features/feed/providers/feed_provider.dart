// KAMOS — Feed provider with cursor pagination + optimistic toast toggle.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/checkin.dart';
import '../repository/feed_repository.dart';

class FeedState {
  const FeedState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<FeedItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  FeedState copyWith({
    List<FeedItem>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      FeedState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future.microtask(refresh);
    return const FeedState(isLoading: true);
  }

  Future<void> refresh() async {
    state = const FeedState(isLoading: true);
    try {
      final page = await ref.read(feedRepositoryProvider).getFeed();
      state = FeedState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on DioException catch (e) {
      state = FeedState(error: _msg(e));
    } catch (e) {
      state = FeedState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .getFeed(cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: _msg(e));
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Optimistic toast toggle. Updates local state immediately, then reconciles
  /// with the server response. On failure, reverts.
  Future<void> toggleToast(String checkinId) async {
    final idx = state.items.indexWhere((i) => i.id == checkinId);
    if (idx == -1) return;
    final item = state.items[idx];
    final optimistic = item.copyWith(
      youToasted: !item.youToasted,
      toasts: item.youToasted ? item.toasts - 1 : item.toasts + 1,
    );
    final next = [...state.items];
    next[idx] = optimistic;
    state = state.copyWith(items: next);

    try {
      final result =
          await ref.read(feedRepositoryProvider).toggleToast(checkinId);
      final settled = [...state.items];
      final stillIdx = settled.indexWhere((i) => i.id == checkinId);
      if (stillIdx != -1) {
        settled[stillIdx] = settled[stillIdx].copyWith(
          toasts: result.toasts,
          youToasted: result.youToasted,
        );
        state = state.copyWith(items: settled);
      }
    } catch (_) {
      // Revert.
      final revert = [...state.items];
      final stillIdx = revert.indexWhere((i) => i.id == checkinId);
      if (stillIdx != -1) {
        revert[stillIdx] = item;
        state = state.copyWith(items: revert);
      }
    }
  }

  String _msg(DioException e) {
    final err = e.error;
    if (err is ApiException) return err.message;
    return e.message ?? 'Request failed';
  }
}

final feedProvider =
    NotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);
