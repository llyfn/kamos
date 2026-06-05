// KAMOS — FlavorTagBrowseSheet (SPEC §4.3, post-redesign per
// `docs/history/03_checkin_compose_redesign/00_brief.md`).
//
// Large modal bottom sheet that lists every flavor tag in a flat, searchable
// list (no dimension grouping). Tapping a row toggles selection in place;
// closing the sheet preserves the selection on the parent. Mirrors the
// JSX prototype in `design/ui_kits/mobile/components/CheckInScreen.jsx`
// (search field + flat list inside a Sheet primitive).
//
// Selection state stays with the parent screen — this widget reads
// `selected` and emits via `onToggle(slug)` for each tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/models/flavor_tag.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/checkin_providers.dart';

/// Opens the flavor-tag browse sheet. The sheet returns no value — selection
/// updates flow through [onToggle] as the user taps rows.
Future<void> showFlavorTagBrowseSheet({
  required BuildContext context,
  required Set<String> selected,
  required void Function(String slug) onToggle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: FlavorTagBrowseSheet(
        selected: selected,
        onToggle: onToggle,
      ),
    ),
  );
}

class FlavorTagBrowseSheet extends ConsumerStatefulWidget {
  const FlavorTagBrowseSheet({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  /// Current selection (slugs). The parent owns this set — this widget
  /// re-renders on every tap because the parent's `setState` rebuilds the
  /// sheet via the open callback.
  final Set<String> selected;

  /// Fires with the toggled slug each time a row is tapped.
  final void Function(String slug) onToggle;

  @override
  ConsumerState<FlavorTagBrowseSheet> createState() =>
      _FlavorTagBrowseSheetState();
}

class _FlavorTagBrowseSheetState extends ConsumerState<FlavorTagBrowseSheet> {
  final _query = TextEditingController();
  // Local mirror of the parent selection so taps repaint instantly without
  // round-tripping a setState through the parent.
  late final Set<String> _selected = {...widget.selected};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String slug) {
    setState(() {
      if (_selected.contains(slug)) {
        _selected.remove(slug);
      } else {
        _selected.add(slug);
      }
    });
    widget.onToggle(slug);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final tagsAsync = ref.watch(flavorTagsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              l.checkInFlavorTags,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: t.fg1,
              ),
            ),
          ),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.checkInFlavorSheetSearch,
              prefixIcon: Icon(Icons.search, color: t.fg3, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Center(
                child: Text(
                  l.errorGeneric,
                  style: TextStyle(color: t.fg3, fontSize: 13),
                ),
              ),
              data: (tags) => _buildList(context, locale, tags),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, String locale, List<FlavorTag> tags) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? tags
        : tags.where((tag) {
            final name = resolveI18n(tag.name, locale).toLowerCase();
            return name.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            l.checkInFlavorSheetEmpty,
            style: TextStyle(color: t.fg3, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final tag = filtered[i];
        final isSelected = _selected.contains(tag.slug);
        return InkWell(
          onTap: () => _toggle(tag.slug),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    resolveI18n(tag.name, locale),
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 15,
                      color: t.fg1,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, color: t.ai, size: 20)
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
