// KAMOS — ProfileRepository. /v1/users/me + public profile.
//
// NOTE: per QA MINOR #8, `GET /v1/users/{username}` returns a `User`
// embedding email. We tolerate the field on the wire (the model is the same)
// but the UI must not display it. The PublicProfile model exposes it on
// `user.email` for future-proofing, but profile screens never read that.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/page.dart';
import '../../../core/models/user.dart';

class ProfileRepository {
  ProfileRepository({required this.dio});
  final Dio dio;

  Future<Me> me() async {
    final res = await dio.get('/v1/users/me');
    return Me.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> updateMe({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? locale,
    String? privacyMode,
  }) async {
    final res = await dio.patch(
      '/v1/users/me',
      data: {
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (locale != null) 'locale': locale,
        if (privacyMode != null) 'privacy_mode': privacyMode,
      },
    );
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteMe() async {
    await dio.delete('/v1/users/me');
  }

  Future<PublicProfile> getProfile(String username) async {
    final res = await dio.get('/v1/users/$username');
    return PublicProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Page<Checkin>> userCheckins(
    String username, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await dio.get(
      '/v1/users/$username/check-ins',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => Checkin.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(dio: ref.read(dioProvider)),
);
