// KAMOS — Follow request inbox (SPEC §5.4). Approve / Decline per row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/social_providers.dart';
import '../repository/social_repository.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(followRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.inboxTitle)),
      body: async.when(
        loading: () => Center(child: LoadingView(label: l.loadingLabel)),
        error: (e, _) => Center(
          child: ErrorView(
            onRetry: () => ref.invalidate(followRequestsProvider),
          ),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyView(title: l.inboxEmptyTitle, body: l.inboxEmptyBody);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = page.items[i];
              return KamosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KamosAvatar(
                          initial: r.displayUsername,
                          size: 44,
                          imageUrl: r.avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.displayName.isEmpty
                                    ? r.displayUsername
                                    : r.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '@${r.username}',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  color: t.fg3,
                                ),
                              ),
                              if ((r.bio ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    r.bio!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.fg2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(socialRepositoryProvider)
                                  .decline(r.userId);
                              ref.invalidate(followRequestsProvider);
                            },
                            child: Text(l.inboxDecline),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(socialRepositoryProvider)
                                  .approve(r.userId);
                              ref.invalidate(followRequestsProvider);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: t.ai,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(l.inboxApprove),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
