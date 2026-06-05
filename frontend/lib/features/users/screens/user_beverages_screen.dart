// KAMOS — User beverages screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/user_beverage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/user_beverages_provider.dart';

const _defaultDirByAxis = <String, String>{
  'rating': 'desc',
  'last_checkin': 'desc',
  'producer': 'asc',
  'category': 'asc',
};

class UserBeveragesScreen extends ConsumerStatefulWidget {
  const UserBeveragesScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<UserBeveragesScreen> createState() =>
      _UserBeveragesScreenState();
}

class _UserBeveragesScreenState extends ConsumerState<UserBeveragesScreen> {
  final _scrollController = ScrollController();

  CategorySlug? _category;
  double? _minRating;
  String _sort = 'rating';
  String _sortDir = 'desc';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  UserBeveragesArgs get _args => UserBeveragesArgs(
    username: widget.username,
    categorySlug: _category == null ? null : categorySlugToWire(_category!),
    minRating: _minRating,
    sort: _sort,
    sortDir: _sortDir,
  );

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(userBeveragesProvider(_args).notifier).loadMore();
    }
  }

  void _resetScroll() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(userBeveragesProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.userBeveragesTitle,
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontWeight: FontWeight.w600,
            color: t.fg1,
          ),
        ),
        actions: [
          _SortMenu(
            sort: _sort,
            sortDir: _sortDir,
            onSelected: _onSortSelected,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            category: _category,
            minRating: _minRating,
            onCategoryChanged: (slug) {
              setState(() => _category = slug);
              _resetScroll();
            },
            onMinRatingChanged: (v) {
              setState(() => _minRating = v);
              _resetScroll();
            },
          ),
          Expanded(
            child: AsyncWidget(
              value: async,
              center: true,
              onRetry: () => ref.invalidate(userBeveragesProvider(_args)),
              data: (state) {
                if (state.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(userBeveragesProvider(_args).future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyView(
                          glyph: '酒',
                          title: l.userBeveragesEmpty,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(userBeveragesProvider(_args).future),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      KamosSpacing.lg,
                      KamosSpacing.sm,
                      KamosSpacing.lg,
                      KamosSpacing.lg,
                    ),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == state.items.length) {
                        return PagingFooter(
                          isLoading: state.isLoadingMore,
                          hasMore: state.hasMore,
                        );
                      }
                      return _UserBeverageRowCard(row: state.items[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onSortSelected(String sort) {
    setState(() {
      if (sort == _sort) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sort = sort;
        _sortDir = _defaultDirByAxis[sort] ?? 'desc';
      }
    });
    _resetScroll();
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.minRating,
    required this.onCategoryChanged,
    required this.onMinRatingChanged,
  });

  final CategorySlug? category;
  final double? minRating;
  final ValueChanged<CategorySlug?> onCategoryChanged;
  final ValueChanged<double?> onMinRatingChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.bgPage,
        border: Border(bottom: BorderSide(color: t.border1)),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: KamosSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KamosSpacing.md),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: KamosChip(
                    label: l.userBeveragesAllCategories,
                    selected: category == null,
                    onTap: () => onCategoryChanged(null),
                  ),
                ),
                for (final slug in CategorySlug.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: KamosChip(
                      label: categoryLabel(context, slug),
                      selected: category == slug,
                      onTap: () => onCategoryChanged(slug),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KamosSpacing.md),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: Text(
                    l.userBeveragesMinRating,
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: t.fg3,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: KamosChip(
                    label: l.userBeveragesAllCategories,
                    selected: minRating == null,
                    onTap: () => onMinRatingChanged(null),
                  ),
                ),
                for (final threshold in const [3.5, 4.0, 4.5])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: KamosChip(
                      label: '≥ ${threshold.toStringAsFixed(1)}',
                      selected: minRating == threshold,
                      onTap: () => onMinRatingChanged(threshold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.sort,
    required this.sortDir,
    required this.onSelected,
  });

  final String sort;
  final String sortDir;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return PopupMenuButton<String>(
      tooltip: l.userBeveragesSort,
      icon: Icon(Icons.sort, color: t.fg1),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(context, 'rating', l.userBeveragesSortRating),
        _item(context, 'last_checkin', l.userBeveragesSortLastCheckin),
        _item(context, 'producer', l.userBeveragesSortProducer),
        _item(context, 'category', l.userBeveragesSortCategory),
      ],
    );
  }

  PopupMenuItem<String> _item(
    BuildContext context,
    String value,
    String label,
  ) {
    final t = context.tokens;
    final active = sort == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            active ? Icons.check : Icons.check_box_outline_blank,
            size: 16,
            color: active ? t.ai : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: t.fg1,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 6),
            Icon(
              sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: t.ai,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserBeverageRowCard extends StatelessWidget {
  const _UserBeverageRowCard({required this.row});

  final UserBeverageRow row;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final b = row.beverage;
    final slug = categorySlugFromString(b.category.slug);
    final catLabel = slug == null
        ? resolveI18n(b.category.labelI18n, locale)
        : categoryLabel(context, slug);

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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(fontSize: 12, color: t.fg2),
                ),
                Text(
                  catLabel,
                  style: TextStyle(fontSize: 12, color: t.fg3),
                ),
                const SizedBox(height: 4),
                _RatingsRow(
                  userAvg: row.userAvgRating,
                  userCount: row.userCheckinCount,
                  globalAvg: row.globalAvgRating,
                  l: l,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.fgMuted),
        ],
      ),
    );
  }
}

class _RatingsRow extends StatelessWidget {
  const _RatingsRow({
    required this.userAvg,
    required this.userCount,
    required this.globalAvg,
    required this.l,
  });

  final double? userAvg;
  final int userCount;
  final double? globalAvg;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const monoStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    final mutedStyle = TextStyle(
      fontFamily: 'NotoSansJP',
      fontSize: 11,
      color: t.fg3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StarsDisplay(value: userAvg, size: 12),
            const SizedBox(width: 6),
            Text(
              userAvg == null
                  ? '—'
                  : l.ratingValue(userAvg!.toStringAsFixed(1)),
              style: monoStyle,
            ),
            const SizedBox(width: 6),
            Text(
              l.userBeveragesYourAvg,
              style: mutedStyle,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            StarsDisplay(value: globalAvg, size: 12),
            const SizedBox(width: 6),
            Text(
              l.userBeveragesGlobalAvg,
              style: mutedStyle,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l.userBeveragesCheckinCount(userCount),
          style: mutedStyle,
        ),
      ],
    );
  }
}
