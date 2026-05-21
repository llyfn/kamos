// KAMOS — PublicCollectionsRepository.
//
// Wraps `GET /v1/collections/public?cursor=...`. The endpoint is OptionalAuth
// (signed-out users can browse) and uses the standard cursor-pagination
// envelope. Items carry both the collection metadata and the owner's slim
// public profile so the discover list can attribute "by {username}" without
// a second request per row.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';

class PublicCollectionsRepository {
  PublicCollectionsRepository(Dio dio) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<Page<CollectionWithOwner>> list({String? cursor}) async {
    final data = await _api.collections.listPublic(cursor: cursor);
    return Page.fromJson(
      data,
      (raw) => CollectionWithOwner.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final publicCollectionsRepositoryProvider =
    Provider<PublicCollectionsRepository>(
      (ref) => PublicCollectionsRepository(ref.read(dioProvider)),
    );
