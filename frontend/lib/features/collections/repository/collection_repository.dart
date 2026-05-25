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

  /// Fetches the signed-in user's collections plus the set of those that
  /// already contain [beverageId]. Used by the beverage-detail "Add to
  /// list" sheet to seed checkbox state.
  ///
  /// No batch-membership endpoint exists in the API yet, so this fans out
  /// one detail call per collection. User collections are small in the
  /// MVP (Inventory + Wishlist + a handful of user-created lists) so the
  /// fan-out is bounded; if a collection has more than 100 entries (the
  /// detail endpoint's max page size) a membership beyond the first page
  /// would not be detected — acceptable for the MVP UX where the user
  /// can still re-add and the server is idempotent.
  Future<({List<Collection> all, Set<String> memberIds})>
  listMineWithMembership(String beverageId) async {
    final page = await list();
    final all = page.items;
    final memberIds = <String>{};
    for (final c in all) {
      try {
        final (_, entries) = await detail(c.id);
        for (final e in entries.items) {
          if (e.beverage.id == beverageId) {
            memberIds.add(c.id);
            break;
          }
        }
      } catch (_) {
        // Treat a per-collection error as "unknown membership"; the
        // sheet still renders the collection unchecked, and a user
        // tap will surface any real failure via the toggle handler.
      }
    }
    return (all: all, memberIds: memberIds);
  }
}

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(dio: ref.watch(dioProvider)),
);
