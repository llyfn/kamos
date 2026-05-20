// KAMOS — PublicCollectionsRepository (Phase 6).
//
// Wraps `GET /v1/collections/public?cursor=...`. The endpoint is OptionalAuth
// (signed-out users can browse) and uses the standard cursor-pagination
// envelope. Items carry both the collection metadata and the owner's slim
// public profile so the discover list can attribute "by {username}" without
// a second request per row.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';

class PublicCollectionsRepository {
  PublicCollectionsRepository(this._dio);
  final Dio _dio;

  Future<Page<CollectionWithOwner>> list({String? cursor}) async {
    final res = await _dio.get(
      '/v1/collections/public',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => CollectionWithOwner.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final publicCollectionsRepositoryProvider =
    Provider<PublicCollectionsRepository>(
  (ref) => PublicCollectionsRepository(ref.read(dioProvider)),
);
