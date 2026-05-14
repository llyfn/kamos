// KAMOS — SocialRepository. Follow toggle, follow requests inbox.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/page.dart';
import '../../../core/models/social.dart';

class SocialRepository {
  SocialRepository({required this.dio});
  final Dio dio;

  Future<FollowResult> follow(String username) async {
    final res = await dio.post('/v1/users/$username/follow');
    return FollowResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> unfollow(String username) async {
    await dio.delete('/v1/users/$username/follow');
  }

  Future<Page<FollowRequest>> requests(
      {String? cursor, int limit = 20}) async {
    final res = await dio.get(
      '/v1/follow-requests',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => FollowRequest.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<void> approve(String userId) async {
    await dio.post('/v1/follow-requests/$userId/approve');
  }

  Future<void> decline(String userId) async {
    await dio.post('/v1/follow-requests/$userId/decline');
  }
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(dio: ref.read(dioProvider)),
);
