// KAMOS — Collection detail (SPEC §6). Contents + rename + delete with
// confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/models/collection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/collection_providers.dart';
import '../repository/collection_repository.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(collectionDetailProvider(collectionId));
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (_) => ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text(l.collectionsRename),
                    onTap: () => Navigator.pop(context, 'rename'),
                  ),
                  ListTile(
                    title: Text(
                      l.collectionsDeleteAction,
                      style: TextStyle(color: t.fgDanger),
                    ),
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                ],
              ),
            );
            if (picked == 'delete' && context.mounted) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(l.collectionsConfirmDelete),
                  content: Text(l.collectionsConfirmDeleteBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.actionCancel),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.akane),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.actionDelete),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(collectionRepositoryProvider)
                    .delete(collectionId);
                ref.invalidate(collectionsProvider);
                if (context.mounted) context.pop();
              }
            }
          },
        ),
      ]),
      body: async.when(
        loading: () => Center(child: LoadingView(label: l.loadingLabel)),
        error: (e, _) => Center(
          child: ErrorView(
            onRetry: () =>
                ref.invalidate(collectionDetailProvider(collectionId)),
          ),
        ),
        data: (record) {
          final (collection, entries) = record;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: t.kinari,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      collection.name.isEmpty ? '?' : collection.name[0],
                      style: TextStyle(
                        fontFamily: 'ShipporiMincho',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: t.fg1,
                          ),
                        ),
                        Text(
                          '${collection.entryCount} · ${l.collectionsPrivate}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: t.fg3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _VisibilityToggle(collection: collection),
              const SizedBox(height: 12),
              if (entries.items.isEmpty)
                EmptyView(
                  glyph: '∅',
                  title: l.collectionsEmptyEntries,
                  body: l.collectionsEmptyEntriesBody,
                )
              else
                ...entries.items.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KamosCard(
                      onTap: () =>
                          context.push('/beverages/${e.beverage.id}'),
                      child: Row(
                        children: [
                          KamosLabel(
                            width: 48,
                            height: 64,
                            tone:
                                labelToneFromCategory(e.beverage.category.slug),
                            imageUrl: e.beverage.labelImageUrl,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resolveI18n(e.beverage.name, locale),
                                  style: const TextStyle(
                                    fontFamily: 'ShipporiMincho',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  resolveI18n(e.beverage.brewery.name, locale),
                                  style: TextStyle(
                                      fontSize: 12, color: t.fg2),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: t.fgMuted),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

/// Phase 6 — public/private toggle for an OWN collection. The current
/// `/collections` tab only lists collections owned by the signed-in user, so
/// reaching this screen implies ownership; the toggle is unconditionally
/// rendered.
class _VisibilityToggle extends ConsumerStatefulWidget {
  const _VisibilityToggle({required this.collection});
  final Collection collection;

  @override
  ConsumerState<_VisibilityToggle> createState() => _VisibilityToggleState();
}

class _VisibilityToggleState extends ConsumerState<_VisibilityToggle> {
  late bool _isPublic = widget.collection.visibility == CollectionVisibility.public;
  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: _isPublic,
      onChanged: _pending ? null : _onChanged,
      title: Text(
        l.collectionVisibilityPublicTitle,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: t.fg1,
        ),
      ),
      subtitle: Text(
        _isPublic
            ? l.collectionVisibilityPublicSubtitle
            : l.collectionVisibilityPrivateSubtitle,
        style: TextStyle(fontSize: 12, color: t.fg3),
      ),
    );
  }

  Future<void> _onChanged(bool value) async {
    final next = value
        ? CollectionVisibility.public
        : CollectionVisibility.private;
    final previous = _isPublic;
    setState(() {
      _isPublic = value;
      _pending = true;
    });
    try {
      await ref
          .read(collectionRepositoryProvider)
          .updateVisibility(widget.collection.id, next);
      ref.invalidate(collectionDetailProvider(widget.collection.id));
      ref.invalidate(collectionsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _isPublic = previous);
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}
