// KAMOS — Check-in card used in the feed list.
//
// Renders avatar + username, beverage label + name + brewery, rating, review
// (truncated @140 chars), tag chips, photo placeholder, kanpai (toast) button.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/models/checkin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/kanpai_button.dart';
import '../../../shared/widgets/stars_display.dart';

class CheckInCard extends StatelessWidget {
  const CheckInCard({
    super.key,
    required this.item,
    required this.onToast,
  });

  final FeedItem item;
  final VoidCallback onToast;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final beverageName = resolveI18n(item.beverage.name, locale);
    final breweryName = resolveI18n(item.beverage.brewery.name, locale);
    final region = item.beverage.brewery.region ?? '';
    final when = parseIsoDateOrNull(item.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KamosCard(
        onTap: () => context.push('/check-ins/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KamosAvatar(
                  initial: item.user.displayUsername,
                  size: 36,
                  imageUrl: item.user.avatarUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.user.displayUsername,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.fg1,
                        ),
                      ),
                      Text(
                        when != null ? elapsedShort(when, l) : '',
                        style: TextStyle(fontSize: 12, color: t.fg3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz, color: t.fg3, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push('/beverages/${item.beverage.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KamosLabel(
                    width: 52,
                    height: 68,
                    tone: labelToneFromCategory(item.beverage.category.slug),
                    imageUrl: item.beverage.labelImageUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beverageName,
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: t.fg1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [breweryName, if (region.isNotEmpty) region].join(' · '),
                          style: TextStyle(fontSize: 12, color: t.fg2),
                        ),
                        if (item.rating != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StarsDisplay(value: item.rating, size: 13),
                              const SizedBox(width: 6),
                              Text(
                                l.ratingValue(item.rating!.toStringAsFixed(1)),
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
            ),
            if ((item.review ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _truncated(item.review!, 140, l.feedMore),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: t.fg1,
                ),
              ),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .map(
                      (tag) => KamosChip(
                        label: resolveI18n(tag.name, locale),
                        kind: KamosChipKind.tag,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (item.photoCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border1),
                  gradient: LinearGradient(
                    colors: [t.kinari, t.gray100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.photo_camera_outlined,
                    color: t.fgMuted, size: 28),
              ),
            ],
            if (item.venue != null) ...[
              const SizedBox(height: 8),
              Text(
                (item.venue!.locality ?? '').isEmpty
                    ? l.feedCardAtVenueNoLocality(item.venue!.name)
                    : l.feedCardAtVenue(
                        item.venue!.name,
                        item.venue!.locality!,
                      ),
                style: TextStyle(fontSize: 12, color: t.fg3),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: t.border1,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                KanpaiButton(
                  count: item.toasts,
                  active: item.youToasted,
                  onTap: onToast,
                ),
                const SizedBox(width: 8),
                _CommentBadge(
                  count: item.commentCount,
                  semanticLabel:
                      l.feedCardCommentsCountLabel(item.commentCount),
                  onTap: () => context.push('/check-ins/${item.id}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _truncated(String text, int max, String moreLabel) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}… $moreLabel';
  }
}

/// Phase 6 — comment count badge mirroring the KanpaiButton silhouette.
/// Renders the comment glyph + numeric count; tapping pushes to the check-in
/// detail.
class _CommentBadge extends StatelessWidget {
  const _CommentBadge({
    required this.count,
    required this.semanticLabel,
    required this.onTap,
  });

  final int count;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: t.border2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mode_comment_outlined, size: 16, color: t.fg2),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
