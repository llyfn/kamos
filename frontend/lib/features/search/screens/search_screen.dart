// KAMOS — Search / Discover (SPEC §7).
//
// File path is search/search_screen.dart for legacy reasons; this screen
// is the Discover tab (route /discover). The folder rename is out of scope.
//
// Full-text search across beverage + producer names. Category chips render
// EXACT SPEC §2.1 strings per locale (`categoryLabel`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/kamos_page_title.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../../shared/widgets/state_views.dart';
import '../../beverages/providers/beverage_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(beverageListProvider.notifier);
    _q.text = ref.read(beverageListProvider).query;
    Future.microtask(() => notifier.refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      ref.read(beverageListProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final state = ref.watch(beverageListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: KamosPageTitle(l.searchHeader),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: t.gray100,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: t.fg3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l.searchPlaceholder,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_q.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: t.fg3),
                        onPressed: () {
                          _q.clear();
                          _onQueryChanged('');
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: KamosChip(
                        label: l.searchCategoryAll,
                        selected: state.category == null,
                        onTap: () => ref
                            .read(beverageListProvider.notifier)
                            .setCategory(null),
                      ),
                    ),
                    for (final slug in CategorySlug.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: KamosChip(
                          label: categoryLabel(context, slug),
                          selected:
                              state.category == categorySlugToWire(slug),
                          onTap: () => ref
                              .read(beverageListProvider.notifier)
                              .setCategory(categorySlugToWire(slug)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.items.length == 1
                        ? l.searchResultCountOne(state.items.length)
                        : l.searchResultCountOther(state.items.length),
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
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const LogoLoader()
                  : state.error != null && state.items.isEmpty
                  ? Center(
                      child: ErrorView(
                        message: l.errorGeneric,
                        onRetry: () =>
                            ref.read(beverageListProvider.notifier).refresh(),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(beverageListProvider.notifier).refresh(),
                      child: state.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                EmptyView(
                                  glyph: '—',
                                  title: l.searchNoResultsTitle,
                                  body: l.searchNoResultsBody,
                                  // Only offer the "suggest a beverage" CTA when
                                  // the user has actually issued a search.
                                  // Cold-start (zero query + no filter) just shows
                                  // the empty copy — the catalog being empty is
                                  // not something the user can suggest their way
                                  // out of.
                                  action:
                                      (_q.text.isNotEmpty || state.category != null)
                                      ? TextButton(
                                          onPressed: () => context.push(
                                            '/beverage-requests/new',
                                          ),
                                          child: Text(l.searchSuggestMissingCta),
                                        )
                                      : null,
                                ),
                              ],
                            )
                          : NotificationListener<ScrollNotification>(
                      onNotification: (s) {
                        if (s.metrics.pixels >=
                            s.metrics.maxScrollExtent - 600) {
                          ref.read(beverageListProvider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: state.items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          if (i == state.items.length) {
                            return PagingFooter(
                              isLoading: state.isLoadingMore,
                              hasMore: state.hasMore,
                            );
                          }
                          final b = state.items[i];
                          final slug = categorySlugFromString(b.category.slug);
                          final catLabel = slug == null
                              ? resolveI18n(b.category.labelI18n, locale)
                              : categoryLabel(context, slug);
                          final sub = b.subcategory == null
                              ? ''
                              : resolveI18n(b.subcategory!.name, locale);
                          final subtitle = sub.isEmpty
                              ? catLabel
                              : '$catLabel · $sub';
                          return KamosCard(
                            onTap: () => context.push('/beverages/${b.id}'),
                            child: Row(
                              children: [
                                KamosLabel(
                                  width: 52,
                                  height: 68,
                                  tone: labelToneFromCategory(b.category.slug),
                                  imageUrl: b.labelImageUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        resolveI18n(b.name, locale),
                                        style: const TextStyle(
                                          fontFamily: 'ShipporiMincho',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        resolveI18n(b.producer.name, locale),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.fg2,
                                        ),
                                      ),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.fg3,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          StarsDisplay(
                                            value: b.avgRating,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 6),
                                          if (b.avgRating != null)
                                            Text(
                                              l.ratingValue(
                                                b.avgRating!.toStringAsFixed(1),
                                              ),
                                              style: const TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: t.fgMuted),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
