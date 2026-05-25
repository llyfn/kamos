// KAMOS — Producer detail screen. i18n name + region + founded + website +
// list of beverages.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_display.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/producer_providers.dart';

class ProducerDetailScreen extends ConsumerWidget {
  const ProducerDetailScreen({super.key, required this.producerId});
  final String producerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(producerDetailProvider(producerId));

    return Scaffold(
      appBar: AppBar(),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(producerDetailProvider(producerId)),
        data: (detail) {
          final producer = detail.producer;
          final name = resolveI18n(producer.name, locale);
          // Migration 016: prefecture is now a nested object that embeds its
          // region. Display the prefecture name (most specific locality).
          final region = producer.prefecture == null
              ? ''
              : resolveI18n(producer.prefecture!.name, locale);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: t.bgWarm,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    Text(
                      l.producerOverline.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                        color: t.fg3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ShipporiMincho',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                    if (region.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(region, style: TextStyle(color: t.fg2)),
                    ],
                    if (producer.foundedYear != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${l.producerFounded} ${producer.foundedYear}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: t.fg3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (producer.description != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          resolveI18n(producer.description!, locale),
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ),
                    if ((producer.website ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          producer.website!.replaceFirst(
                            RegExp(r'^https?://'),
                            '',
                          ),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: t.fgLink,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Text(
                      l.producerBeverages,
                      style: TextStyle(
                        fontFamily: 'ShipporiMincho',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.fg1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (detail.beverages.items.isEmpty)
                      EmptyView(title: l.producerNoBeverages)
                    else
                      ...detail.beverages.items.map((b) {
                        final n = resolveI18n(b.name, locale);
                        final cat = categorySlugFromString(b.category.slug);
                        final catLabel = cat == null
                            ? resolveI18n(b.category.labelI18n, locale)
                            : categoryLabel(context, cat);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: KamosCard(
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
                                        n,
                                        style: const TextStyle(
                                          fontFamily: 'ShipporiMincho',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        catLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.fg2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
