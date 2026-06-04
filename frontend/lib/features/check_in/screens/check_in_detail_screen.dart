// KAMOS — Check-in detail screen.
//
// A minimal feed-card-style header (user, beverage, rating, review, flavor
// tags, photos) plus the comments section beneath. Reachable from the feed
// at `/check-ins/{id}`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/models/checkin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../comments/providers/comment_providers.dart';
import '../../comments/widgets/comments_section.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../users/navigation.dart';
import '../providers/checkin_providers.dart';
import '../repository/checkin_repository.dart';

class CheckInDetailScreen extends ConsumerWidget {
  const CheckInDetailScreen({super.key, required this.checkInId});
  final String checkInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(checkInDetailProvider(checkInId));
    final me = ref.watch(meProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (async.asData != null &&
              me != null &&
              async.asData!.value.user.id == me.user.id)
            _OwnDetailMenu(checkin: async.asData!.value),
        ],
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(checkInDetailProvider(checkInId)),
        data: (checkin) {
          final when = parseIsoDateOrNull(checkin.createdAt);
          final beverageName = resolveI18n(checkin.beverage.name, locale);
          final producerName = resolveI18n(
            checkin.beverage.producer.name,
            locale,
          );
          return RefreshIndicator(
            onRefresh: () async {
              // Two providers back this screen: the check-in itself (header
              // card) and the comments thread underneath. Refresh both in
              // parallel so the spinner is honest about end-of-load.
              await Future.wait<void>([
                ref.refresh(checkInDetailProvider(checkInId).future),
                ref.refresh(commentsProvider(checkin.id).future),
              ]);
            },
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: KamosCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => pushUserProfile(
                              context,
                              checkin.user.username,
                            ),
                            child: KamosAvatar(
                              initial: checkin.user.displayUsername,
                              size: 36,
                              imageUrl: checkin.user.avatarUrl,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => pushUserProfile(
                                    context,
                                    checkin.user.username,
                                  ),
                                  child: Text(
                                    checkin.user.displayUsername,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: t.fg1,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      when != null ? elapsedShort(when, l) : '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.fg3,
                                      ),
                                    ),
                                    if (checkin.editedAt != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        l.editedMarker,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: t.fg3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () =>
                            context.push('/beverages/${checkin.beverage.id}'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KamosLabel(
                              width: 52,
                              height: 68,
                              tone: labelToneFromCategory(
                                checkin.beverage.category.slug,
                              ),
                              imageUrl: checkin.beverage.labelImageUrl,
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
                                      color: t.fg1,
                                    ),
                                  ),
                                  Text(
                                    producerName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.fg2,
                                    ),
                                  ),
                                  if (checkin.rating != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        StarsDisplay(
                                          value: checkin.rating,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l.ratingValue(
                                            checkin.rating!.toStringAsFixed(1),
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((checkin.review ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          checkin.review!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: t.fg1,
                          ),
                        ),
                      ],
                      if (checkin.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: checkin.tags
                              .map(
                                (tag) => KamosChip(
                                  label: resolveI18n(tag.name, locale),
                                  kind: KamosChipKind.tag,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (checkin.photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in checkin.photos)
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: t.border1),
                                  image: p.url.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(p.url),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              CommentsSection(checkInId: checkin.id),
            ],
          ),
          );
        },
      ),
    );
  }
}

/// Own-check-in overflow action menu mirrored from the feed card. Sits in
/// the detail screen's AppBar and surfaces Edit + Delete affordances. Only
/// rendered when the viewer is the author.
class _OwnDetailMenu extends ConsumerWidget {
  const _OwnDetailMenu({required this.checkin});
  final Checkin checkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(Icons.more_horiz, size: 22, color: t.fg2),
      onPressed: () => _showSheet(context, ref, l),
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
      await context.push('/check-ins/${checkin.id}/edit');
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
        await ref.read(checkInRepositoryProvider).delete(checkin.id);
        ref.invalidate(feedProvider);
        ref.invalidate(userCheckinsProvider(checkin.user.username));
        if (!context.mounted) return;
        context.pop();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.checkInPostFailed)));
      }
    }
  }
}
