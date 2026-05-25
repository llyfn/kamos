// KAMOS — Beverage detail screen. Renders catalog info, avg rating,
// aggregated flavor, recent check-ins.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/beverage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/kamos_pill_button.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/beverage_providers.dart';
import '../widgets/collection_picker_sheet.dart';

class BeverageDetailScreen extends ConsumerWidget {
  const BeverageDetailScreen({super.key, required this.beverageId});
  final String beverageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(beverageDetailProvider(beverageId));

    return Scaffold(
      appBar: AppBar(),
      body: AsyncWidget(
        value: asyncDetail,
        center: true,
        onRetry: () => ref.invalidate(beverageDetailProvider(beverageId)),
        data: (detail) => _Body(detail: detail),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final BeverageDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final b = detail.beverage;
    final name = resolveI18n(b.name, locale);
    final brewery = resolveI18n(b.brewery.name, locale);
    // Migration 016: per-beverage prefecture/region are gone; derive from the
    // nested brewery.prefecture. Display the prefecture name (most specific).
    final region = b.brewery.prefecture == null
        ? ''
        : resolveI18n(b.brewery.prefecture!.name, locale);
    final slug = categorySlugFromString(b.category.slug);
    final categoryLabelText = slug == null
        ? resolveI18n(b.category.labelI18n, locale)
        : categoryLabel(context, slug);
    final sub = b.subcategory == null
        ? ''
        : resolveI18n(b.subcategory!, locale);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: KamosLabel(
              width: 140,
              height: 184,
              tone: labelToneFromCategory(b.category.slug),
              imageUrl: b.labelImageUrl,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '$categoryLabelText${sub.isNotEmpty ? ' · $sub' : ''}'
                  .toUpperCase(),
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
                color: t.fg3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ShipporiMincho',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: t.fg1,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () => context.push('/breweries/${b.brewery.id}'),
              child: Text(
                [brewery, if (region.isNotEmpty) region].join(' · '),
                style: TextStyle(color: t.fgLink, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StarsDisplay(value: b.avgRating, size: 16),
              const SizedBox(width: 8),
              if (b.avgRating != null)
                Text(
                  l.ratingValue(b.avgRating!.toStringAsFixed(1)),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '· ${b.checkInCount}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: t.fg3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              KamosPillButton.primary(
                label: l.checkInCta,
                onPressed: () => context.push('/check-in', extra: b),
              ),
              const SizedBox(width: 8),
              KamosPillButton.secondary(
                label: l.beverageDetailAddToList,
                icon: Icons.bookmark_outline,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => CollectionPickerSheet(beverage: b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.bgWarm,
              border: Border.all(color: t.border1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (b.abv != null)
                  _Stat(
                    label: l.beverageDetailAbv,
                    value: '${b.abv!.toStringAsFixed(1)}%',
                  ),
                if (b.polishingRatio != null)
                  _Stat(
                    label: l.beverageDetailSeimai,
                    value: '${b.polishingRatio}%',
                  ),
                if (region.isNotEmpty)
                  _Stat(label: l.beverageDetailRegion, value: region),
                if (sub.isNotEmpty)
                  _Stat(label: l.beverageDetailType, value: sub),
              ],
            ),
          ),
          if (detail.aggregatedFlavor.isNotEmpty) ...[
            _SectionHeader(text: l.beverageDetailAggregatedFlavor),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detail.aggregatedFlavor
                  .map(
                    (f) => KamosChip(
                      label: resolveI18n(f.name, locale),
                      kind: KamosChipKind.tag,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (b.description != null) ...[
            _SectionHeader(text: l.beverageDetailAbout),
            Text(
              resolveI18n(b.description!, locale),
              style: TextStyle(fontSize: 14, height: 1.6, color: t.fg1),
            ),
          ],
          _SectionHeader(text: l.beverageDetailRecent),
          if (detail.recentCheckIns.isEmpty)
            EmptyView(
              title: l.beverageNoCheckinsTitle,
              body: l.beverageNoCheckinsBody,
            )
          else
            ...detail.recentCheckIns.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KamosCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KamosAvatar(
                        initial: r.user.displayUsername,
                        size: 32,
                        imageUrl: r.user.avatarUrl,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.user.displayUsername,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (r.rating != null)
                                  Text(
                                    l.ratingValue(r.rating!.toStringAsFixed(1)),
                                    style: const TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            if ((r.review ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                r.review!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'NotoSansJP',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: t.fg3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.fg1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'ShipporiMincho',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: t.fg1,
        ),
      ),
    );
  }
}
