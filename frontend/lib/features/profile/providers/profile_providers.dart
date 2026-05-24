// KAMOS — Profile providers. `meProvider` is long-lived; the public-profile
// and recent-check-ins providers are autoDispose.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/checkin.dart';
import '../../../core/models/user.dart';
import '../../check_in/repository/checkin_repository.dart';
import '../repository/profile_repository.dart';

final meProvider = FutureProvider<Me>((ref) async {
  return ref.read(profileRepositoryProvider).me();
});

final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>((ref, username) async {
      return ref.read(profileRepositoryProvider).getProfile(username);
    });

/// Latest 10 check-ins for a given user, keyed by **username** (the backend
/// route is `GET /v1/users/{username}/check-ins`). `autoDispose` so the
/// list does not pin stale data after navigating away from a profile.
///
/// Wave 2 agent B's check-in submit flow invalidates this provider for the
/// signed-in user so the Me profile's recent list refreshes on return —
/// keep the signature stable (`family<List<Checkin>, String>` keyed by
/// username).
final userCheckinsProvider = FutureProvider.autoDispose
    .family<List<Checkin>, String>((ref, username) async {
      return ref.read(checkInRepositoryProvider).listForUser(
            username,
            limit: 10,
          );
    });
