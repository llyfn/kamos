// KAMOS — CollectionsRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';

class CollectionRepository {
  CollectionRepository({required this.dio});
  final Dio dio;

  Future<Page<Collection>> list() async {
    final res = await dio.get('/v1/collections');
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => Collection.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<Collection> create(String name) async {
    final res = await dio.post('/v1/collections', data: {'name': name});
    return Collection.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Collection> rename(String id, String name) async {
    final res = await dio.patch('/v1/collections/$id', data: {'name': name});
    return Collection.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await dio.delete('/v1/collections/$id');
  }

  /// Returns the collection plus its first page of entries.
  Future<(Collection, Page<CollectionEntry>)> detail(String id) async {
    final res = await dio.get('/v1/collections/$id');
    final data = res.data as Map<String, dynamic>;
    final entries = data['entries'] is Map<String, dynamic>
        ? Page.fromJson(
            data['entries'] as Map<String, dynamic>,
            (raw) => CollectionEntry.fromJson(raw as Map<String, dynamic>),
          )
        : const Page<CollectionEntry>(items: []);
    return (Collection.fromJson(data), entries);
  }

  Future<void> addEntry(String collectionId, String beverageId,
      {String? note}) async {
    await dio.post(
      '/v1/collections/$collectionId/entries',
      data: {
        'beverage_id': beverageId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> removeEntry(String collectionId, String beverageId) async {
    await dio.delete('/v1/collections/$collectionId/entries/$beverageId');
  }
}

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(dio: ref.read(dioProvider)),
);
