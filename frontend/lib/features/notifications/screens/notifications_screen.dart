// KAMOS — Notifications screen (SPEC §5.4, design/notifications_ux.md).
//
// Tab root. Cursor-paginated, 20 per page. Mark-on-scroll fires when a row
// is ≥ 50% visible for ≥ 500ms (design §3.1) — the screen owns a 1s
// debounced batch that collects the eligible ids and fires one
// `POST /v1/notifications/read` per batch. Already-read rows are filtered
// out by the provider before the request goes out.
//
// "Mark all read" fires immediately on tap with no confirmation
// (design §3.3) — low-stakes, reversible-by-context action; rows
// crossfade from unread→read in unison and the bottom-nav dot clears.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../models/notification.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_row.dart';

/// 50% visible fraction for ≥ 500ms qualifies a row as "read" per design §3.1.
const double _kReadVisibleFraction = 0.5;
const Duration _kReadVisibleDwell = Duration(milliseconds: 500);

/// Batch mark-read calls over 1s so a single page-fill doesn't fire 20
/// individual POSTs. The 1s window is design-aligned with the dwell timer
/// — it's long enough to coalesce a fast scroll-through and short enough
/// that the user perceives the row state change as "instant".
const Duration _kMarkReadBatchWindow = Duration(seconds: 1);

/// Prefetch the next page when we're within this many viewports of the end.
const double _kPrefetchViewports = 1.5;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();

  // Mark-on-scroll bookkeeping. `_dwellTimers` keeps a per-id 500ms timer
  // that fires when the row has been ≥ 50% visible for the full dwell. A
  // visibility-drop callback cancels the timer for that id. `_pending` is
  // the batch the dwell timers feed into; `_batchTimer` drains the batch
  // to the server once per second.
  final Map<String, Timer> _dwellTimers = {};
  final Set<String> _pending = {};
  Timer? _batchTimer;

  double _viewportHeight = 600.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportHeight = MediaQuery.sizeOf(context).height;
  }

  @override
  void dispose() {
    for (final t in _dwellTimers.values) {
      t.cancel();
    }
    _dwellTimers.clear();
    _batchTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onRowVisibility(KamosNotification n, double fraction) {
    if (!n.isUnread) return;
    final id = n.id;
    if (fraction >= _kReadVisibleFraction) {
      // Start (or keep running) the 500ms dwell timer.
      if (_dwellTimers.containsKey(id)) return;
      _dwellTimers[id] = Timer(_kReadVisibleDwell, () {
        _dwellTimers.remove(id);
        _queueMarkRead(id);
      });
    } else {
      // Visibility dropped before the dwell elapsed — reset.
      _dwellTimers.remove(id)?.cancel();
    }
  }

  void _queueMarkRead(String id) {
    _pending.add(id);
    _batchTimer ??= Timer(_kMarkReadBatchWindow, _flushBatch);
  }

  void _flushBatch() {
    _batchTimer = null;
    if (_pending.isEmpty) return;
    final ids = _pending.toList(growable: false);
    _pending.clear();
    ref.read(notificationListProvider.notifier).markRead(ids);
  }

  bool _onScrollEnd(ScrollEndNotification n) {
    final pos = n.metrics;
    final remaining = pos.maxScrollExtent - pos.pixels;
    if (remaining <= _viewportHeight * _kPrefetchViewports) {
      ref.read(notificationListProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: t.bgPage,
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          async.when(
            data: (state) {
              final hasUnread = state.items.any((n) => n.isUnread);
              return TextButton(
                onPressed: hasUnread
                    ? () => ref
                        .read(notificationListProvider.notifier)
                        .markAllRead()
                    : null,
                child: Text(l.notificationsMarkAllRead),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(notificationListProvider.notifier).refresh(),
          child: async.when(
            loading: () => const LogoLoader(),
            error: (_, _) => Center(
              child: ErrorView(
                onRetry: () =>
                    ref.read(notificationListProvider.notifier).refresh(),
              ),
            ),
            data: (state) {
              if (state.items.isEmpty) {
                // Wrap the empty view in a list view so pull-to-refresh
                // works without items (RefreshIndicator needs a scrollable).
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: _viewportHeight * 0.12),
                    EmptyView(
                      glyph: '通',
                      title: l.notificationsEmptyTitle,
                      body: l.notificationsEmptyBody,
                    ),
                  ],
                );
              }
              return NotificationListener<ScrollEndNotification>(
                onNotification: _onScrollEnd,
                child: ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    KamosSpacing.lg,
                    KamosSpacing.sm,
                    KamosSpacing.lg,
                    KamosSpacing.lg,
                  ),
                  itemCount: state.items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: KamosSpacing.sm),
                  itemBuilder: (_, i) {
                    if (i == state.items.length) {
                      return PagingFooter(
                        isLoading: state.isLoadingMore,
                        hasMore: state.hasMore,
                      );
                    }
                    final n = state.items[i];
                    return VisibilityDetector(
                      key: Key('notification-${n.id}'),
                      onVisibilityChanged: (info) =>
                          _onRowVisibility(n, info.visibleFraction),
                      child: NotificationRow(notification: n),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
