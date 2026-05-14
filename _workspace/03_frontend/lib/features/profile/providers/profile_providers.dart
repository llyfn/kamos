// KAMOS — Profile providers. `meProvider` is long-lived; the public-profile
// provider is autoDispose.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../repository/profile_repository.dart';

final meProvider = FutureProvider<Me>((ref) async {
  return ref.read(profileRepositoryProvider).me();
});

final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>((ref, username) async {
  return ref.read(profileRepositoryProvider).getProfile(username);
});
