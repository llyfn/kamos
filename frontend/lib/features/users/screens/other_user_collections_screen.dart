// KAMOS — Other user's public collections screen.
//
// Cursor-paginated list of the named user's visible collections. Server-side
// gating: owner-as-viewer sees all rows; every other viewer sees only public
// rows (no client filtering needed). Tap navigates to `/collections/:id`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/users_providers.dart';

class OtherUserCollectionsScreen extends ConsumerStatefulWidget {
  const OtherUserCollectionsScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<OtherUserCollectionsScreen> createState() =>
      _OtherUserCollectionsScreenState();
}

class _OtherUserCollectionsScreenState
    extends ConsumerState<OtherUserCollectionsScreen> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref
          .read(otherUserCollectionsProvider(widget.username).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(otherUserCollectionsProvider(widget.username));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.userCollectionsTitle(widget.username),
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontWeight: FontWeight.w600,
            color: t.fg1,
          ),
        ),
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () =>
            ref.invalidate(otherUserCollectionsProvider(widget.username)),
        data: (state) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(
              otherUserCollectionsProvider(widget.username).future,
            ),
            child: state.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyView(
                        glyph: '集',
                        title: l.publicCollectionsEmpty,
                      ),
                    ],
                  )
                : ListView.builder(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(KamosSpacing.lg),
            itemCount: state.items.length + 1,
            itemBuilder: (context, i) {
              if (i == state.items.length) {
                return PagingFooter(
                  isLoading: state.isLoadingMore,
                  hasMore: state.hasMore,
                );
              }
              final c = state.items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KamosCard(
                  onTap: () => context.push('/collections/${c.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: t.kinari,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.name.isEmpty ? '?' : c.name[0],
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: t.fg1,
                          ),
                        ),
                      ),
                      const SizedBox(width: KamosSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontFamily: 'ShipporiMincho',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.entryCount == 1
                                  ? l.collectionsBottleCountOne(c.entryCount)
                                  : l.collectionsBottleCountOther(c.entryCount),
                              style: TextStyle(fontSize: 12, color: t.fg2),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: t.fgMuted),
                    ],
                  ),
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}
