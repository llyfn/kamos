// KAMOS — Search / Discover (SPEC §7).
//
// Full-text search across beverage + brewery names. Category chips render
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
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../beverages/providers/beverage_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  String? _category;

  @override
  void initState() {
    super.initState();
    // Bootstrap the listing with no filter.
    Future.microtask(
      () => ref.read(beverageListProvider.notifier).refresh(),
    );
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.searchHeader,
                  style: TextStyle(
                    fontFamily: 'ShipporiMincho',
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: t.fg1,
                  ),
                ),
              ),
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
                        selected: _category == null,
                        onTap: () {
                          setState(() => _category = null);
                          ref
                              .read(beverageListProvider.notifier)
                              .setCategory(null);
                        },
                      ),
                    ),
                    for (final slug in CategorySlug.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: KamosChip(
                          label: categoryLabel(context, slug),
                          selected: _category == categorySlugToWire(slug),
                          onTap: () {
                            final wire = categorySlugToWire(slug);
                            setState(() => _category = wire);
                            ref
                                .read(beverageListProvider.notifier)
                                .setCategory(wire);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? Center(child: LoadingView(label: l.loadingLabel))
                  : state.error != null && state.items.isEmpty
                      ? Center(
                          child: ErrorView(
                            message: l.errorGeneric,
                            onRetry: () => ref
                                .read(beverageListProvider.notifier)
                                .refresh(),
                          ),
                        )
                      : state.items.isEmpty
                          ? EmptyView(
                              glyph: '—',
                              title: l.searchNoResultsTitle,
                              body: l.searchNoResultsBody,
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (s) {
                                if (s.metrics.pixels >=
                                    s.metrics.maxScrollExtent - 600) {
                                  ref
                                      .read(beverageListProvider.notifier)
                                      .loadMore();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: state.items.length + 1,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  if (i == state.items.length) {
                                    return PagingFooter(
                                      isLoading: state.isLoadingMore,
                                      hasMore: state.hasMore,
                                    );
                                  }
                                  final b = state.items[i];
                                  final slug = categorySlugFromString(
                                      b.category.slug);
                                  final catLabel = slug == null
                                      ? resolveI18n(
                                          b.category.labelI18n, locale)
                                      : categoryLabel(context, slug);
                                  return KamosCard(
                                    onTap: () => context
                                        .push('/beverages/${b.id}'),
                                    child: Row(
                                      children: [
                                        KamosLabel(
                                          width: 52,
                                          height: 68,
                                          tone: labelToneFromCategory(
                                              b.category.slug),
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
                                                  fontFamily:
                                                      'ShipporiMincho',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                resolveI18n(
                                                    b.brewery.name, locale),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: t.fg2),
                                              ),
                                              Text(
                                                catLabel,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: t.fg3,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  StarsDisplay(
                                                      value: b.avgRating,
                                                      size: 12),
                                                  const SizedBox(width: 6),
                                                  if (b.avgRating != null)
                                                    Text(
                                                      l.ratingValue(b
                                                          .avgRating!
                                                          .toStringAsFixed(1)),
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'JetBrainsMono',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right,
                                            color: t.fgMuted),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
