// KAMOS — Followers / Following provider.
//
// One AsyncNotifier family covers both screens; the `kind` arg picks the
// followers vs following endpoint. `q` is the optional prefix filter the
// server applies against `username` + `display_name`. The screen
// debounces typing (~250 ms) before flipping `q`, which is what
// distinguishes one notifier key from the next here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page.dart';
import '../../../core/models/social.dart';
import '../repository/users_repository.dart';

enum SocialListKind { followers, following }

/// Family key for `socialListProvider`. Value-equality means equal args
/// land on the same notifier instance — required for stable infinite
/// scroll across rebuilds.
class SocialListArgs {
  const SocialListArgs({
    required this.username,
    required this.kind,
    this.q = '',
  });

  final String username;
  final SocialListKind kind;
  final String q;

  @override
  bool operator ==(Object other) =>
      other is SocialListArgs &&
      other.username == username &&
      other.kind == kind &&
      other.q == q;

  @override
  int get hashCode => Object.hash(username, kind, q);
}

class SocialListState {
  const SocialListState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<SocialUser> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  SocialListState copyWith({
    List<SocialUser>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) => SocialListState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class SocialListNotifier extends AsyncNotifier<SocialListState> {
  SocialListNotifier(this.args);
  final SocialListArgs args;

  Future<Page<SocialUser>> _fetch({String? cursor}) {
    final repo = ref.read(usersRepositoryProvider);
    final q = args.q.isEmpty ? null : args.q;
    return args.kind == SocialListKind.followers
        ? repo.getFollowers(args.username, cursor: cursor, q: q)
        : repo.getFollowing(args.username, cursor: cursor, q: q);
  }

  @override
  Future<SocialListState> build() async {
    final page = await _fetch();
    return SocialListState(
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
      final page = await _fetch(cursor: current.nextCursor);
      state = AsyncValue.data(
        SocialListState(
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

final socialListProvider =
    AsyncNotifierProvider.family<
      SocialListNotifier,
      SocialListState,
      SocialListArgs
    >(SocialListNotifier.new);
