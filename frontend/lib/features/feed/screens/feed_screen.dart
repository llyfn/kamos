// KAMOS — Feed screen. Cursor-paginated infinite scroll (page size 20).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/feed_provider.dart';
import '../widgets/check_in_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

// Stage 5 (PERF-032 / STYLE-027): the prefetch heuristic is "trigger
// loadMore when the viewport is within 1.5 screens of the end". The
// 280px-per-item magic constant is gone — viewport-derived threshold
// is correct at any item height and any screen size.
const double _kFeedPrefetchViewports = 1.5;

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();
  double _viewportHeight = 600.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Memoize the viewport height once per dependency change; reading
    // MediaQuery.sizeOf inside the scroll callback would rebuild the
    // chain on every notification.
    _viewportHeight = MediaQuery.sizeOf(context).height;
  }

  bool _onScrollEnd(ScrollEndNotification n) {
    final pos = n.metrics;
    final remaining = pos.maxScrollExtent - pos.pixels;
    if (remaining <= _viewportHeight * _kFeedPrefetchViewports) {
      ref.read(feedProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final state = ref.watch(feedProvider);

    if (state.isLoading && state.items.isEmpty) {
      return Center(child: LoadingView(label: l.actionLoadingMore));
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: ErrorView(
          message: state.error,
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(feedProvider.notifier).refresh(forceRefresh: true),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.feedHeader,
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: t.fg1,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          l.feedSubheader,
                          style: TextStyle(fontSize: 12, color: t.fg3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/inbox'),
                    icon: const Icon(Icons.notifications_none_outlined),
                  ),
                ],
              ),
            ),
            if (state.items.isEmpty)
              EmptyView(
                glyph: '醸',
                title: l.feedEmptyTitle,
                body: l.feedEmptyBody,
              )
            else ...[
              for (final item in state.items)
                CheckInCard(
                  item: item,
                  onToast: () =>
                      ref.read(feedProvider.notifier).toggleToast(item.id),
                ),
              if (state.isLoadingMore)
                LoadingView(label: l.actionLoadingMore)
              else if (!state.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Text(
                      '— ${l.actionEndOfFeed} —',
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                        color: t.fg3,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
