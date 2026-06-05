// Full-page picker for flavor profile tags.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/models/flavor_tag.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../providers/checkin_providers.dart';

class FlavorProfilesPickerScreen extends ConsumerStatefulWidget {
  const FlavorProfilesPickerScreen({super.key, required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<FlavorProfilesPickerScreen> createState() =>
      _FlavorProfilesPickerScreenState();
}

class _FlavorProfilesPickerScreenState
    extends ConsumerState<FlavorProfilesPickerScreen> {
  late final Set<String> _selected = {...widget.initial};
  final _query = TextEditingController();

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
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final tagsAsync = ref.watch(flavorTagsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(_selected),
        ),
        title: Text(l.flavorProfilesPageTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            data: (tags) => _buildBody(context, l, t, locale, tags),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l,
    KamosTokens t,
    String locale,
    List<FlavorTag> tags,
  ) {
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? tags
        : tags.where((tag) {
            return resolveI18n(tag.name, locale).toLowerCase().contains(q);
          }).toList();
    final selectedTags = [
      for (final tag in tags)
        if (_selected.contains(tag.slug)) tag,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l.flavorProfilesSearchHint,
            prefixIcon: Icon(Icons.search, color: t.fg3, size: 20),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (selectedTags.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              l.flavorProfilesSelectedLabel.toUpperCase(),
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
                color: t.fg1,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in selectedTags)
                KamosChip(
                  label: resolveI18n(tag.name, locale),
                  selected: true,
                  onTap: () => _toggle(tag.slug),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in filtered)
                  KamosChip(
                    label: resolveI18n(tag.name, locale),
                    selected: _selected.contains(tag.slug),
                    onTap: () => _toggle(tag.slug),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
