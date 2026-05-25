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
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../comments/widgets/comments_section.dart';
import '../providers/checkin_providers.dart';

class CheckInDetailScreen extends ConsumerWidget {
  const CheckInDetailScreen({super.key, required this.checkInId});
  final String checkInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(checkInDetailProvider(checkInId));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(checkInDetailProvider(checkInId)),
        data: (checkin) {
          final when = parseIsoDateOrNull(checkin.createdAt);
          final beverageName = resolveI18n(checkin.beverage.name, locale);
          final breweryName = resolveI18n(
            checkin.beverage.brewery.name,
            locale,
          );
          return ListView(
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
                            onTap: () => context.push(
                              '/users/${checkin.user.username}',
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
                                  onTap: () => context.push(
                                    '/users/${checkin.user.username}',
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
                                Text(
                                  when != null ? elapsedShort(when, l) : '',
                                  style: TextStyle(fontSize: 12, color: t.fg3),
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
                                    breweryName,
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
          );
        },
      ),
    );
  }
}
