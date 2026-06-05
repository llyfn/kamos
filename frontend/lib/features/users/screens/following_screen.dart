// KAMOS — Following screen (slice D).
//
// Same shape as `FollowersScreen` — both rely on the shared
// `SocialListView` body. The `kind` parameter selects the right
// endpoint via `socialListProvider`.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/social_list_provider.dart';
import 'social_list_view.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SocialListView(
      username: username,
      kind: SocialListKind.following,
      title: l.socialFollowingTitle,
      emptyTitle: l.socialEmptyFollowing,
    );
  }
}
