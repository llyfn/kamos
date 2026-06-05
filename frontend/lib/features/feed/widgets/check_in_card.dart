// KAMOS — Shared check-in card. Used by feed, beverage detail, and profile.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../check_in/repository/checkin_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../users/navigation.dart';
import '../providers/feed_providers.dart';

class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key, required this.item, required this.onToast});

  final FeedItem item;
  final VoidCallback onToast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final me = ref.watch(meProvider).asData?.value;
    final isOwn = me != null && me.user.id == item.user.id;
    final beverageName = resolveI18n(item.beverage.name, locale);
    final producerName = resolveI18n(item.beverage.producer.name, locale);
    final when = parseIsoDateOrNull(item.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: KamosSpacing.md),
      child: KamosCard(
        onTap: () => context.push('/check-ins/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // HitTestBehavior.opaque so taps on the transparent gap
                // between avatar and text are absorbed by this gesture
                // instead of bubbling to the card-level open-detail tap.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      pushUserProfile(context, item.user.username),
                  child: KamosAvatar(
                    initial: item.user.displayUsername,
                    size: 36,
                    imageUrl: item.user.avatarUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/check-ins/${item.id}'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        if (when != null)
                          _TimestampRow(
                            label: elapsedShort(when, l),
                            edited: item.editedAt != null,
                            editedLabel: l.editedMarker,
                            tokens: t,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KamosSpacing.md),
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
                  const SizedBox(width: KamosSpacing.md),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (item.beverage.producer.imageUrl != null) ...[
                              _ProducerThumb(
                                url: item.beverage.producer.imageUrl!,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                producerName,
                                style: TextStyle(fontSize: 12, color: t.fg2),
                              ),
                            ),
                          ],
                        ),
                        if (item.rating != null) ...[
                          const SizedBox(height: 6),
                          _StarRatingChip(
                            value: item.rating!,
                            starSize: 13,
                            label: l.ratingValue(
                              item.rating!.toStringAsFixed(1),
                            ),
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
                style: TextStyle(fontSize: 14, height: 1.55, color: t.fg1),
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
            if (item.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CheckInPhotoGrid(photos: item.photos),
            ],
            if (item.venue != null) ...[
              const SizedBox(height: KamosSpacing.sm),
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
            const SizedBox(height: KamosSpacing.md),
            Container(height: 1, color: t.border1),
            const SizedBox(height: 10),
            Row(
              children: [
                KanpaiButton(
                  count: item.toasts,
                  active: item.youToasted,
                  onTap: onToast,
                ),
                const SizedBox(width: KamosSpacing.sm),
                _CommentBadge(
                  count: item.commentCount,
                  semanticLabel: l.feedCardCommentsCountLabel(
                    item.commentCount,
                  ),
                  onTap: () => context.push('/check-ins/${item.id}'),
                ),
                if (isOwn) ...[
                  const Spacer(),
                  _OwnCheckInMenu(item: item),
                ],
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

class _TimestampRow extends StatelessWidget {
  const _TimestampRow({
    required this.label,
    required this.edited,
    required this.editedLabel,
    required this.tokens,
  });

  final String label;
  final bool edited;
  final String editedLabel;
  final KamosTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: tokens.fg3)),
        if (edited) ...[
          const SizedBox(width: 4),
          Text(
            editedLabel,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: tokens.fg3,
            ),
          ),
        ],
      ],
    );
  }
}

class _StarRatingChip extends StatelessWidget {
  const _StarRatingChip({
    required this.value,
    required this.starSize,
    required this.label,
  });

  final double value;
  final double starSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarsDisplay(value: value, size: starSize),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProducerThumb extends StatelessWidget {
  const _ProducerThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const size = 16.0;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (size * dpr).round(),
          memCacheHeight: (size * dpr).round(),
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Stage 5 (PERF-022): renders 1-4 photos at the bottom of a check-in
/// card. Single-photo layouts go full-bleed; multi-photo layouts use
/// a tight 2- or 2x2-column grid. We pin memCacheWidth to the logical
/// width * devicePixelRatio so cached_network_image stores a properly-
/// sized bitmap instead of a full-resolution JPEG.
class _CheckInPhotoGrid extends StatelessWidget {
  const _CheckInPhotoGrid({required this.photos});

  final List<PhotoRef> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final totalWidth = MediaQuery.sizeOf(context).width;
    // Subtract the KamosCard horizontal padding (token spacing); 32px
    // is the steady-state in the design system.
    final usableWidth = (totalWidth - 32).clamp(120.0, totalWidth);

    if (photos.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _PhotoTile(
          url: photos.first.url,
          memCacheWidth: (usableWidth * dpr).round(),
          aspectRatio: 16 / 9,
        ),
      );
    }
    // 2-up or 2x2 grid.
    final cols = photos.length == 2 ? 2 : 2;
    final tileWidth = (usableWidth - (cols - 1) * 4) / cols;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: photos
          .take(4)
          .map(
            (p) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _PhotoTile(
                url: p.url,
                memCacheWidth: (tileWidth * dpr).round(),
                aspectRatio: 1,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.memCacheWidth,
    required this.aspectRatio,
  });

  final String url;
  final int memCacheWidth;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: memCacheWidth,
        placeholder: (context, _) => Container(color: t.gray100),
        errorWidget: (context, _, _) => Container(
          color: t.gray100,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, size: 20, color: t.fgMuted),
        ),
      ),
    );
  }
}

class _OwnCheckInMenu extends ConsumerWidget {
  const _OwnCheckInMenu({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _showSheet(context, ref, l),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.more_horiz, size: 18, color: t.fg3),
      ),
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.checkInEdit),
              onTap: () => Navigator.pop(sheetCtx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.checkInDelete),
              onTap: () => Navigator.pop(sheetCtx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      if (!context.mounted) return;
      await context.push('/check-ins/${item.id}/edit');
    } else if (action == 'delete') {
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text(l.checkInDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(l.checkInDelete),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await ref.read(checkInRepositoryProvider).delete(item.id);
        ref.invalidate(feedProvider);
        ref.invalidate(userCheckinsProvider(item.user.username));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.checkInPostFailed)));
      }
    }
  }
}

/// Comment count badge mirroring the KanpaiButton silhouette. Renders
/// the comment glyph + numeric count; tapping pushes to the check-in
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
