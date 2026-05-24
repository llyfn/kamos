// KAMOS — Beverage-detail "Add to list" bottom sheet.
//
// Renders the signed-in user's collections with a checkbox per row that
// reflects current membership for [beverage]. Tapping a row toggles the
// membership via the collections API (POST entries to add, DELETE to
// remove) and re-invalidates [myCollectionsForBeverageProvider] so the
// next render reflects the server state.
//
// This sheet is opened from `beverage_detail_screen.dart` via
// `showModalBottomSheet`. It is distinct from the older multi-select
// `features/collections/sheets/collection_picker_sheet.dart` which had a
// different staging-then-save UX. This version mutates per-tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/collection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../collections/providers/collection_providers.dart';
import '../../collections/repository/collection_repository.dart';
import '../providers/beverage_providers.dart';

class CollectionPickerSheet extends ConsumerStatefulWidget {
  const CollectionPickerSheet({super.key, required this.beverage});
  final Beverage beverage;

  @override
  ConsumerState<CollectionPickerSheet> createState() =>
      _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends ConsumerState<CollectionPickerSheet> {
  /// Per-collection in-flight flag — disables the row's checkbox while the
  /// add/remove round-trip is pending so a rapid double-tap doesn't fire
  /// two mutations.
  final Set<String> _pending = <String>{};

  Future<void> _toggle({
    required Collection collection,
    required bool currentlyMember,
  }) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(collectionRepositoryProvider);
    setState(() => _pending.add(collection.id));
    try {
      if (currentlyMember) {
        await repo.removeEntry(collection.id, widget.beverage.id);
      } else {
        await repo.addEntry(collection.id, widget.beverage.id);
      }
      ref.invalidate(myCollectionsForBeverageProvider(widget.beverage.id));
      ref.invalidate(collectionsProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.beverageListSheetSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(collection.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(
      myCollectionsForBeverageProvider(widget.beverage.id),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.beverageListSheetTitle,
                      style: TextStyle(
                        fontFamily: 'ShipporiMincho',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: AsyncWidget(
                  value: async,
                  onRetry: () => ref.invalidate(
                    myCollectionsForBeverageProvider(widget.beverage.id),
                  ),
                  data: (state) {
                    if (state.all.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            l.beverageListSheetEmpty,
                            style: TextStyle(color: t.fg2),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.all.length,
                      itemBuilder: (_, i) {
                        final c = state.all[i];
                        final isMember = state.memberIds.contains(c.id);
                        final pending = _pending.contains(c.id);
                        return CheckboxListTile(
                          title: Text(c.name),
                          subtitle: Text('${c.entryCount}'),
                          value: isMember,
                          activeColor: t.ai,
                          // Disabled while a mutation is in flight so the
                          // user can't queue conflicting toggles.
                          onChanged: pending
                              ? null
                              : (_) => _toggle(
                                  collection: c,
                                  currentlyMember: isMember,
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
