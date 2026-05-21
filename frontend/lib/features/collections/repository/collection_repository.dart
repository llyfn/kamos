// KAMOS — CollectionsRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';

/// Wraps the `collections` tag of [KamosApi] (list / detail / create /
/// rename / delete / add+remove entries / visibility) and lifts
/// `DioException` into typed `core/api/api_exceptions.dart` exceptions.
/// Used by the collections feature's list + detail screens and the
/// picker sheet.
class CollectionRepository {
  CollectionRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  Future<Page<Collection>> list() async {
    final data = await _api.collections.list();
    return Page.fromJson(
      data,
      (raw) => Collection.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<Collection> create(String name) async {
    final data = await _api.collections.create(name);
    return Collection.fromJson(data);
  }

  Future<Collection> rename(String id, String name) async {
    final data = await _api.collections.patch(id, {'name': name});
    return Collection.fromJson(data);
  }

  /// Updates only the `visibility` field. The server accepts a partial
  /// PATCH; sending `visibility` alone leaves `name` untouched.
  Future<Collection> updateVisibility(
    String id,
    CollectionVisibility visibility,
  ) async {
    final data = await _api.collections.patch(id, {
      'visibility': visibility.toWire(),
    });
    return Collection.fromJson(data);
  }

  Future<void> delete(String id) => _api.collections.delete(id);

  /// Returns the collection plus its first page of entries.
  Future<(Collection, Page<CollectionEntry>)> detail(String id) async {
    final data = await _api.collections.detail(id);
    final entries = data['entries'] is Map<String, dynamic>
        ? Page.fromJson(
            data['entries'] as Map<String, dynamic>,
            (raw) => CollectionEntry.fromJson(raw as Map<String, dynamic>),
          )
        : const Page<CollectionEntry>(items: []);
    return (Collection.fromJson(data), entries);
  }

  Future<void> addEntry(
    String collectionId,
    String beverageId, {
    String? note,
  }) => _api.collections.addEntry(collectionId, beverageId, note: note);

  Future<void> removeEntry(String collectionId, String beverageId) =>
      _api.collections.removeEntry(collectionId, beverageId);
}

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(dio: ref.read(dioProvider)),
);
