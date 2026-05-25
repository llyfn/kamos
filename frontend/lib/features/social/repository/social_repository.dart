// KAMOS — SocialRepository. Follow / unfollow + follow-request approve / decline.
//
// The follow-request inbox listing moved into the notifications surface
// (SPEC §5.4) as `follow_request` rows; this repository keeps the mutating
// approve / decline endpoints because the notification row still calls them.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/social.dart';

class SocialRepository {
  SocialRepository({required Dio dio}) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<FollowResult> follow(String username) async {
    final data = await _api.social.follow(username);
    return FollowResult.fromJson(data);
  }

  Future<void> unfollow(String username) => _api.social.unfollow(username);

  Future<void> approve(String userId) =>
      _api.social.approveFollowRequest(userId);

  Future<void> decline(String userId) =>
      _api.social.declineFollowRequest(userId);
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(dio: ref.watch(dioProvider)),
);
