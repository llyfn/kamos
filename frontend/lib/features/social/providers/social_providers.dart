// KAMOS — Social providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page.dart';
import '../../../core/models/social.dart';
import '../repository/social_repository.dart';

final followRequestsProvider = FutureProvider<Page<FollowRequest>>((ref) async {
  return ref.read(socialRepositoryProvider).requests();
});
