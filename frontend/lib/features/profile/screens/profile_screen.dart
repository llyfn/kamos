// KAMOS — Profile screen (me + other) (SPEC §3.2, §6.3).
//
// `display_username` is rendered for casing; `handle` (lowercase) appears as
// the @-mention. Locale toggle is a SegmentedControl mirroring the JSX kit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/profile_providers.dart';

class MeProfileScreen extends ConsumerWidget {
  const MeProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(meProvider);
    return Scaffold(
      body: async.when(
        loading: () => Center(child: LoadingView(label: l.loadingLabel)),
        error: (e, _) => Center(
          child: ErrorView(
            message: l.errorGeneric,
            onRetry: () => ref.invalidate(meProvider),
          ),
        ),
        data: (me) => _ProfileBody(user: me.user, stats: me.stats, isMe: true),
      ),
    );
  }
}

class OtherProfileScreen extends ConsumerWidget {
  const OtherProfileScreen({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(publicProfileProvider(username));
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        loading: () => Center(child: LoadingView(label: l.loadingLabel)),
        error: (e, _) => Center(
          child: ErrorView(
            message: l.errorGeneric,
            onRetry: () => ref.invalidate(publicProfileProvider(username)),
          ),
        ),
        data: (p) => _ProfileBody(user: p.user, stats: p.stats, isMe: false),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.stats,
    required this.isMe,
  });

  final User user;
  final UserStats stats;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Center(
            child: KamosAvatar(
              initial: user.displayUsername,
              size: 84,
              imageUrl: user.avatarUrl,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              user.displayName.isEmpty ? user.displayUsername : user.displayName,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: t.fg1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              '@${user.username}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: t.fg3,
              ),
            ),
          ),
          if (user.privacyMode == 'private') ...[
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.bgTintMizu,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.profilePrivate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.kon,
                  ),
                ),
              ),
            ),
          ],
          if ((user.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  user.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.fg2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(l.profileStatCheckins, stats.checkins),
              _StatTile(l.profileStatUnique, stats.unique),
              _StatTile(l.profileStatFollowers, stats.followers),
              _StatTile(l.profileStatFollowing, stats.following),
            ],
          ),
          const SizedBox(height: 18),
          if (isMe)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/me/edit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.ai,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l.profileEdit),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => context.push('/me/settings'),
                  child: Text(l.profileSettings),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.profileRecent.toUpperCase(),
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
                color: t.fg3,
              ),
            ),
          ),
          // The actual recent-check-ins list is fetched by a separate provider;
          // for MVP-launch parity we just leave a calm empty until that page
          // is wired (qa-inspector will track).
          EmptyView(
            title: l.beverageNoCheckinsTitle,
            body: l.beverageNoCheckinsBody,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: t.bgWarm,
          border: Border.all(color: t.border1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: t.fg1,
              ),
            ),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: t.fg3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
