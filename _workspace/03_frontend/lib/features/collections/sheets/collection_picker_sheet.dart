// KAMOS — Collection picker sheet (SPEC §6.3). Multi-select.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/collection.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/collection_providers.dart';
import '../repository/collection_repository.dart';

class CollectionPickerSheet extends ConsumerStatefulWidget {
  const CollectionPickerSheet({
    super.key,
    required this.beverageId,
    required this.initialIds,
  });

  final String beverageId;
  final Set<String> initialIds;

  @override
  ConsumerState<CollectionPickerSheet> createState() =>
      _CollectionPickerSheetState();
}

class _CollectionPickerSheetState
    extends ConsumerState<CollectionPickerSheet> {
  late Set<String> _picked;
  final _nameController = TextEditingController();
  bool _creating = false;
  List<Collection> _local = const [];
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _picked = Set.from(widget.initialIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(collectionsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(child: Text(l.errorGeneric)),
        ),
        data: (page) {
          if (!_hydrated) {
            _local = List.from(page.items);
            _hydrated = true;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.collectionsAddTo,
                style: TextStyle(
                  fontFamily: 'ShipporiMincho',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.fg1,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _local.length,
                  itemBuilder: (_, i) {
                    final c = _local[i];
                    final on = _picked.contains(c.id);
                    return CheckboxListTile(
                      title: Text(c.name),
                      subtitle: Text('${c.entryCount}'),
                      value: on,
                      activeColor: t.ai,
                      onChanged: (_) => setState(() {
                        if (on) {
                          _picked.remove(c.id);
                        } else {
                          _picked.add(c.id);
                        }
                      }),
                    );
                  },
                ),
              ),
              if (_creating)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          hintText: l.collectionsNamePlaceholder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;
                        final created = await ref
                            .read(collectionRepositoryProvider)
                            .create(name);
                        if (mounted) {
                          setState(() {
                            _local = [..._local, created];
                            _picked.add(created.id);
                            _creating = false;
                            _nameController.clear();
                          });
                        }
                      },
                      child: Text(l.actionSave),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _creating = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.collectionsCreateNew),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.actionCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        for (final id in _picked) {
                          await ref.read(collectionRepositoryProvider).addEntry(
                                id,
                                widget.beverageId,
                              );
                        }
                        ref.invalidate(collectionsProvider);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: t.ai,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(l.actionSave),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
