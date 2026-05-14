// KAMOS — FeedRepository. Cursor pagination, page size 20 (SPEC §5.2).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/page.dart';

class FeedRepository {
  FeedRepository({required this.dio});
  final Dio dio;

  Future<Page<FeedItem>> getFeed({String? cursor, int limit = 20}) async {
    final res = await dio.get(
      '/v1/feed',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => FeedItem.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<ToastState> toggleToast(String checkinId) async {
    final res = await dio.post('/v1/check-ins/$checkinId/toast');
    return ToastState.fromJson(res.data as Map<String, dynamic>);
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(dio: ref.read(dioProvider)),
);
