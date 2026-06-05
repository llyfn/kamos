// KAMOS — Followers screen (slice D).
//
// Cursor-paginated list of accepted followers for the named user with an
// optional case-insensitive prefix search across `username` +
// `display_name`. Search typing is debounced ~250 ms before the args
// key flips, so each unique `q` is its own notifier instance — paged
// state never bleeds between queries.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/social_list_provider.dart';
import 'social_list_view.dart';

class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SocialListView(
      username: username,
      kind: SocialListKind.followers,
      title: l.socialFollowersTitle,
      emptyTitle: l.socialEmptyFollowers,
    );
  }
}
