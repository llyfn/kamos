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
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(dio: ref.watch(dioProvider)),
);
