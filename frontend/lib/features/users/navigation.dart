// KAMOS — Profile navigation helper.
//
// Always go through this helper instead of pushing `/users/$username`
// directly. Pushing to `/users/:self` would land on `OtherProfileScreen`
// instead of `MeProfileScreen` AND stack a duplicate `NoTransitionPage`
// key on top of the existing `/me` shell tab, crashing the navigator with
// `keyReservation.contains(key)`. The helper swaps to `context.go('/me')`
// (which replaces location) when the target resolves to the signed-in user.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/providers/profile_providers.dart';

/// Navigate to `username`'s profile. Goes to `/me` when `username` matches
/// the signed-in user.
void pushUserProfile(BuildContext context, String username) {
  final container = ProviderScope.containerOf(context);
  final me = container.read(meProvider).asData?.value;
  final isSelf =
      me != null &&
      me.user.username.toLowerCase() == username.toLowerCase();
  if (isSelf) {
    context.go('/me');
  } else {
    context.push('/users/$username');
  }
}
