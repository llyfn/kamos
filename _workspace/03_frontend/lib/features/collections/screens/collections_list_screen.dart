// KAMOS — Collections list (SPEC §6).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/collection_providers.dart';
import '../repository/collection_repository.dart';

class CollectionsListScreen extends ConsumerWidget {
  const CollectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(collectionsProvider);
    return Scaffold(
      body: async.when(
        loading: () => Center(child: LoadingView(label: l.loadingLabel)),
        error: (e, _) => Center(
          child: ErrorView(onRetry: () => ref.invalidate(collectionsProvider)),
        ),
        data: (page) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.collectionsHeader,
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: t.fg1,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _newCollectionName(context, l);
                      if (name != null && name.isNotEmpty) {
                        await ref
                            .read(collectionRepositoryProvider)
                            .create(name);
                        ref.invalidate(collectionsProvider);
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l.collectionsNewList),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                EmptyView(
                  glyph: '集',
                  title: l.collectionsEmptyTitle,
                  body: l.collectionsEmptyBody,
                )
              else
                ...page.items.map((c) {
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
                          const SizedBox(width: 12),
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
                                Text(
                                  '${c.entryCount == 1 ? l.collectionsBottleCountOne(c.entryCount) : l.collectionsBottleCountOther(c.entryCount)} · ${l.collectionsPrivate}',
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

Future<String?> _newCollectionName(BuildContext context, AppLocalizations l) {
  final controller = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l.collectionsCreateNew),
      content: TextField(
        controller: controller,
        maxLength: 50,
        decoration: InputDecoration(hintText: l.collectionsNamePlaceholder),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(l.actionSave),
        ),
      ],
    ),
  );
}
