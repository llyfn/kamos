// KAMOS — SocialRepository. Follow toggle, follow requests inbox.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/page.dart';
import '../../../core/models/social.dart';

/// Wraps the `social` tag of [KamosApi] (follow / unfollow, follow
/// requests inbox, accept + reject) and lifts `DioException` into typed
/// `core/api/api_exceptions.dart` exceptions. Used by the social feature's
/// inbox screen and profile-follow buttons.
class SocialRepository {
  SocialRepository({required Dio dio}) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<FollowResult> follow(String username) async {
    final data = await _api.social.follow(username);
    return FollowResult.fromJson(data);
  }

  Future<void> unfollow(String username) => _api.social.unfollow(username);

  Future<Page<FollowRequest>> requests({String? cursor, int limit = 20}) async {
    final data = await _api.social.followRequests(
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => FollowRequest.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<void> approve(String userId) =>
      _api.social.approveFollowRequest(userId);

  Future<void> decline(String userId) =>
      _api.social.declineFollowRequest(userId);
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(dio: ref.read(dioProvider)),
);
