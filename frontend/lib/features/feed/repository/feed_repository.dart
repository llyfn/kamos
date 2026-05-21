// KAMOS — FeedRepository. Cursor pagination, page size 20 (SPEC §5.2).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/page.dart';

class FeedRepository {
  FeedRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  /// Fetches a page of the feed.
  ///
  /// When [forceRefresh] is `true` [KamosApi.feed] decorates the outgoing
  /// request with the `kBypassCache` extras, which makes
  /// `dio_cache_interceptor` skip its in-memory cache for this call. Wired
  /// into the feed's pull-to-refresh gesture so a user-initiated refresh
  /// always round-trips to the origin.
  Future<Page<FeedItem>> getFeed({
    String? cursor,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final data = await _api.feed.getFeed(
      cursor: cursor,
      limit: limit,
      forceRefresh: forceRefresh,
    );
    return Page.fromJson(
      data,
      (raw) => FeedItem.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<ToastState> toggleToast(String checkinId) async {
    final data = await _api.checkins.toggleToast(checkinId);
    return ToastState.fromJson(data);
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(dio: ref.read(dioProvider)),
);
