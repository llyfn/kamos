// KAMOS — Beverage detail screen. Renders catalog info, avg rating,
// aggregated flavor, recent check-ins.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/photo_ref.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
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
                child: _RecentCheckinRow(summary: r, locale: locale),
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

/// Recent check-in row on the beverage detail page. Renders header (avatar
/// + username → user profile), timestamp, review, photo strip (up to 4),
/// and tag/serving chips. The whole card taps to `/check-ins/:id`; the
/// avatar + username subtree has an opaque nested gesture that pushes to
/// `/users/:username` instead. Designer spec: `profile_social_ux_expansion.md` §4.
class _RecentCheckinRow extends StatelessWidget {
  const _RecentCheckinRow({required this.summary, required this.locale});

  final CheckinSummary summary;
  final String locale;

  String? _servingLabel(BuildContext context) {
    final s = summary.servingStyle;
    if (s == null || s.isEmpty) return null;
    final l = AppLocalizations.of(context);
    return switch (s) {
      'glass' => l.checkInServingGlass,
      'carafe' => l.checkInServingCarafe,
      'bottle' => l.checkInServingBottle,
      'can' => l.checkInServingCan,
      'other' => l.checkInServingOther,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final when = parseIsoDateOrNull(summary.createdAt);
    final servingLabel = _servingLabel(context);

    return KamosCard(
      // Whole-card tap → check-in detail. The avatar + username subtree
      // below has its own opaque GestureDetector that wins the gesture
      // arena for that sub-region and pushes to the author's profile.
      onTap: () => context.push('/check-ins/${summary.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/users/${summary.user.username}'),
            child: KamosAvatar(
              initial: summary.user.displayUsername,
              size: 32,
              imageUrl: summary.user.avatarUrl,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          context.push('/users/${summary.user.username}'),
                      child: Text(
                        summary.user.displayUsername,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (summary.rating != null)
                      Text(
                        l.ratingValue(summary.rating!.toStringAsFixed(1)),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (when != null) ...[
                  const SizedBox(height: KamosSpacing.xs),
                  Text(
                    elapsedShort(when, l),
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 11,
                      color: t.fg3,
                    ),
                  ),
                ],
                if ((summary.review ?? '').isNotEmpty) ...[
                  const SizedBox(height: KamosSpacing.sm),
                  Text(
                    _truncate(summary.review!, 140),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: t.fg1,
                    ),
                  ),
                ],
                if (summary.photos.isNotEmpty) ...[
                  const SizedBox(height: KamosSpacing.sm),
                  _PhotoStrip(photos: summary.photos),
                ],
                if (servingLabel != null || summary.tags.isNotEmpty) ...[
                  const SizedBox(height: KamosSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (servingLabel != null)
                        KamosChip(
                          label: servingLabel,
                          kind: KamosChipKind.tag,
                        ),
                      ...summary.tags.map(
                        (tag) => KamosChip(
                          label: resolveI18n(tag.name, locale),
                          kind: KamosChipKind.tag,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }
}

/// Horizontal strip of up to 4 square photo thumbnails (64×64). No
/// scrolling — the row is fixed-width and the strip taps via the parent
/// card to the full check-in detail (which renders the full gallery).
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<PhotoRef> photos;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final tiles = photos.take(4).toList();
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: KamosSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CachedNetworkImage(
                  imageUrl: tiles[i].url,
                  fit: BoxFit.cover,
                  memCacheWidth: (64 * dpr).round(),
                  placeholder: (_, _) => Container(color: t.gray100),
                  errorWidget: (_, _, _) => Container(
                    color: t.gray100,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 18,
                      color: t.fgMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
