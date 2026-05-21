// KAMOS — ProfileRepository. /v1/users/me + public profile.
//
// NOTE: per QA MINOR #8, `GET /v1/users/{username}` returns a `User`
// embedding email. We tolerate the field on the wire (the model is the same)
// but the UI must not display it. The PublicProfile model exposes it on
// `user.email` for future-proofing, but profile screens never read that.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/page.dart';
import '../../../core/models/user.dart';

class ProfileRepository {
  ProfileRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  Future<Me> me() async {
    final data = await _api.users.getMe();
    return Me.fromJson(data);
  }

  Future<User> updateMe({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? locale,
    String? privacyMode,
  }) async {
    final data = await _api.users.updateMe(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
      locale: locale,
      privacyMode: privacyMode,
    );
    return User.fromJson(data);
  }

  Future<void> deleteMe() => _api.users.deleteMe();

  Future<PublicProfile> getProfile(String username) async {
    final data = await _api.users.getUser(username);
    return PublicProfile.fromJson(data);
  }

  Future<Page<Checkin>> userCheckins(
    String username, {
    String? cursor,
    int limit = 20,
  }) async {
    final data = await _api.users.getUserCheckins(
      username,
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => Checkin.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(dio: ref.read(dioProvider)),
);
