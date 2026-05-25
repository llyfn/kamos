// KAMOS — Profile screen (me + other) (SPEC §3.2, §6.3).
//
// `display_username` is rendered for casing; `handle` (lowercase) appears as
// the @-mention. Locale toggle is a SegmentedControl mirroring the JSX kit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/kamos_pill_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../feed/widgets/check_in_card.dart';
import '../providers/profile_providers.dart';

class MeProfileScreen extends ConsumerWidget {
  const MeProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(meProvider);
    return Scaffold(
      // AppBar background matches the page so the shell + scroll surface read
      // as a single quiet plane. Tints/elevations are zeroed so Material 3
      // doesn't paint a surface seam on scroll.
      appBar: AppBar(
        backgroundColor: t.bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.person_search_outlined, size: 24),
          tooltip: l.userSearchTitle,
          color: t.fg1,
          onPressed: () => context.push('/users/search'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline, size: 24),
            tooltip: l.tabLists,
            color: t.fg1,
            onPressed: () => context.push('/collections'),
          ),
        ],
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(meProvider),
        data: (me) =>
            _ProfileBody(user: me.user, stats: me.stats, isMe: true),
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
    final t = context.tokens;
    final async = ref.watch(publicProfileProvider(username));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline, size: 24),
            tooltip: l.userCollectionsTitle(username),
            color: t.fg1,
            onPressed: () => context.push('/users/$username/lists'),
          ),
        ],
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(publicProfileProvider(username)),
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
              user.displayName.isEmpty
                  ? user.displayUsername
                  : user.displayName,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          // IntrinsicHeight gives every _StatTile the row's max content
          // height so single-line and scaled-down labels still produce a
          // visually even row.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatTile(l.profileStatCheckins, stats.checkins),
                _StatTile(l.profileStatUnique, stats.unique),
                _StatTile(l.profileStatFollowers, stats.followers),
                _StatTile(l.profileStatFollowing, stats.following),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isMe)
            Row(
              children: [
                KamosPillButton.primary(
                  label: l.profileEdit,
                  onPressed: () => context.push('/me/edit'),
                ),
                const SizedBox(width: 8),
                KamosPillButton.secondary(
                  label: l.profileSettings,
                  onPressed: () => context.push('/me/settings'),
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
          _RecentCheckins(username: user.username),
        ],
      ),
    );
  }
}

/// Renders the latest 10 check-ins for [username] using the same
/// [CheckInCard] the feed uses. Lifts `Checkin` → `FeedItem` for the
/// shared card. Empty / loading / error states are calm and inline so
/// the surrounding profile chrome (avatar, name, stats, action pills)
/// never disappears.
class _RecentCheckins extends ConsumerWidget {
  const _RecentCheckins({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(userCheckinsProvider(username));
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return EmptyView(
            title: l.beverageNoCheckinsTitle,
            body: l.beverageNoCheckinsBody,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in items)
              CheckInCard(
                item: _checkinToFeedItem(c),
                onToast: () {
                  // Toast toggling lives on the dedicated feed/detail
                  // surfaces; recent-check-ins on the profile is a
                  // read-only summary.
                },
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ErrorView(
          message: l.errorGeneric,
          onRetry: () => ref.invalidate(userCheckinsProvider(username)),
        ),
      ),
    );
  }
}

/// Lifts a [Checkin] into the [FeedItem] shape consumed by
/// [CheckInCard]. The card only reads fields that exist on both models,
/// so this is a structural translation, not a data fetch.
FeedItem _checkinToFeedItem(Checkin c) => FeedItem(
  id: c.id,
  user: c.user,
  beverage: c.beverage,
  rating: c.rating,
  review: c.review,
  tags: c.tags,
  photos: c.photos,
  venue: c.venue,
  toasts: c.toasts,
  youToasted: c.youToasted,
  commentCount: c.commentCount,
  createdAt: c.createdAt,
);

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
          // Center single-line content within IntrinsicHeight-driven
          // tile height so short and longer-label tiles balance.
          mainAxisAlignment: MainAxisAlignment.center,
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
            // FittedBox(scaleDown) + maxLines:1 keeps "FOLLOWERS"/
            // "FOLLOWING" (and ja/ko equivalents) on a single line at
            // narrow tile widths instead of wrapping to two lines and
            // breaking row height parity with the other tiles.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: t.fg3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
