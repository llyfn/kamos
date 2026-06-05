// KAMOS — UsersRepository.
//
// Wraps the user-search and per-user-collections endpoints. The user-profile
// + user-checkins endpoints live in `features/profile/repository/profile_repository.dart`
// because they were established before this feature; we keep that boundary
// stable rather than churning every existing call site.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';
import '../../../core/models/social.dart';
import '../../../core/models/user_beverage.dart';
import '../models/public_user.dart';

class UsersRepository {
  UsersRepository({required Dio dio}) : _api = KamosApi(dio);
  final KamosApi _api;

  /// `q.length < 2` short-circuits to an empty page locally so the call
  /// site can show an "initial / empty" state without waiting for the
  /// server's 400.
  Future<Page<PublicUser>> search({
    required String q,
    String? cursor,
    int limit = 20,
  }) async {
    final trimmed = q.trim();
    if (trimmed.length < 2) {
      return const Page<PublicUser>(items: [], hasMore: false);
    }
    final data = await _api.users.searchUsers(
      q: trimmed,
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => PublicUser.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<Page<Collection>> collections(
    String username, {
    String? cursor,
    int limit = 20,
  }) async {
    final data = await _api.users.getUserCollections(
      username,
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => Collection.fromJson(raw as Map<String, dynamic>),
    );
  }

  /// Distinct-beverage aggregation for the named user. `categorySlug`,
  /// `producerId`, and `minRating` are server-side filters; `sort`
  /// defaults to `rating` (DESC NULLS LAST per the OpenAPI spec).
  Future<Page<UserBeverageRow>> getUserBeverages(
    String username, {
    String? cursor,
    String? categorySlug,
    String? producerId,
    double? minRating,
    String sort = 'rating',
    String? sortDir,
    int limit = 20,
  }) async {
    final data = await _api.users.getUserBeverages(
      username,
      cursor: cursor,
      category: categorySlug,
      producerId: producerId,
      minRating: minRating,
      sort: sort,
      sortDir: sortDir,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => UserBeverageRow.fromJson(raw as Map<String, dynamic>),
    );
  }

  /// Followers list with optional case-insensitive prefix filter on
  /// `username` + `display_name`. The server enforces 1 ≤ q ≤ 30.
  Future<Page<SocialUser>> getFollowers(
    String username, {
    String? cursor,
    String? q,
    int limit = 20,
  }) async {
    final data = await _api.users.getUserFollowers(
      username,
      cursor: cursor,
      q: q,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => SocialUser.fromJson(raw as Map<String, dynamic>),
    );
  }

  /// Following list with optional prefix filter. See [getFollowers].
  Future<Page<SocialUser>> getFollowing(
    String username, {
    String? cursor,
    String? q,
    int limit = 20,
  }) async {
    final data = await _api.users.getUserFollowing(
      username,
      cursor: cursor,
      q: q,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => SocialUser.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(dio: ref.watch(dioProvider)),
);
