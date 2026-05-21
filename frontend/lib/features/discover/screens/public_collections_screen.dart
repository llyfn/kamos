// KAMOS — Public collections discovery.
//
// Paginated list of public collections from `GET /v1/collections/public`. Each
// row shows the collection name, bottle count, and the owner's display
// username. Tapping a row navigates to `/collections/:id`, which already
// renders the entries list — server-side access checks gate which entries are
// visible (server still returns the full list for a public collection).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/public_collections_providers.dart';

class PublicCollectionsScreen extends ConsumerStatefulWidget {
  const PublicCollectionsScreen({super.key});

  @override
  ConsumerState<PublicCollectionsScreen> createState() =>
      _PublicCollectionsScreenState();
}

class _PublicCollectionsScreenState
    extends ConsumerState<PublicCollectionsScreen> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(publicCollectionsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(publicCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.publicCollectionsTitle,
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
        onRetry: () => ref.read(publicCollectionsProvider.notifier).refresh(),
        data: (state) {
          if (state.items.isEmpty) {
            return EmptyView(glyph: '集', title: l.publicCollectionsEmpty);
          }
          return ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.all(KamosSpacing.lg),
            itemCount: state.items.length + 1,
            itemBuilder: (context, i) {
              if (i == state.items.length) {
                return PagingFooter(
                  isLoading: state.isLoadingMore,
                  hasMore: state.hasMore,
                );
              }
              final item = state.items[i];
              final c = item.collection;
              final owner = item.owner;
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                KamosAvatar(
                                  initial: owner.displayUsername,
                                  size: 18,
                                  imageUrl: owner.avatarUrl,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l.publicCollectionsByOwner(
                                    owner.displayUsername,
                                  ),
                                  style: TextStyle(fontSize: 12, color: t.fg3),
                                ),
                              ],
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
          );
        },
      ),
    );
  }
}
