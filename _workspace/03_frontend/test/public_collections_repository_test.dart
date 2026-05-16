// KAMOS — PublicCollectionsRepository tests (Phase 6).
//
// Drives `GET /v1/collections/public` through a custom Dio adapter. Verifies:
// * 200 → parsed Page<CollectionWithOwner> with owner attribution.
// * `cursor` is forwarded as a query parameter when provided and omitted when
//   the cursor is null/empty.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/collection.dart';
import 'package:kamos/features/discover/repository/public_collections_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.body});

  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Dio _dio(_Adapter adapter) {
  return Dio(BaseOptions(
    baseUrl: 'https://api.test',
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ))
    ..httpClientAdapter = adapter;
}

void main() {
  group('PublicCollectionsRepository.list', () {
    test('parses items + page envelope and omits cursor when null', () async {
      final adapter = _Adapter(body: const {
        'items': [
          {
            'id': 'c1',
            'owner_id': 'u1',
            'name': 'Late autumn picks',
            'entry_count': 5,
            'visibility': 'public',
            'owner': {
              'id': 'u1',
              'username': 'mai',
              'display_username': 'Mai',
              'display_name': 'Mai Tanaka',
              'avatar_url': null,
            },
          },
          {
            'id': 'c2',
            'owner_id': 'u2',
            'name': 'Honjozo only',
            'entry_count': 12,
            'visibility': 'public',
            'owner': {
              'id': 'u2',
              'username': 'jiro',
              'display_username': 'Jiro',
              'display_name': 'Jiro Sato',
            },
          },
        ],
        'next_cursor': 'c2',
        'has_more': true,
      });
      final repo = PublicCollectionsRepository(_dio(adapter));

      final page = await repo.list();

      expect(page.items, hasLength(2));
      expect(page.items.first.collection.id, 'c1');
      expect(page.items.first.collection.name, 'Late autumn picks');
      expect(page.items.first.owner.username, 'mai');
      expect(page.items.first.owner.displayUsername, 'Mai');
      expect(page.items.first.owner.displayName, 'Mai Tanaka');
      expect(page.items[1].owner.displayUsername, 'Jiro');
      expect(page.items[1].owner.displayName, 'Jiro Sato');
      expect(page.nextCursor, 'c2');
      expect(page.hasMore, isTrue);

      final req = adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, '/v1/collections/public');
      expect(req.queryParameters.containsKey('cursor'), isFalse);
    });

    test('forwards cursor as a query parameter when provided', () async {
      final adapter = _Adapter(body: const {
        'items': [],
        'next_cursor': null,
        'has_more': false,
      });
      final repo = PublicCollectionsRepository(_dio(adapter));

      await repo.list(cursor: 'abc');

      expect(adapter.lastRequest!.queryParameters['cursor'], 'abc');
    });

    test('CollectionOwner.fromJson round-trips display_name', () {
      final owner = CollectionOwner.fromJson(const {
        'id': 'u7',
        'username': 'kazu',
        'display_username': 'Kazu',
        'display_name': 'Kazuki Mori',
        'avatar_url': null,
      });
      expect(owner.id, 'u7');
      expect(owner.username, 'kazu');
      expect(owner.displayUsername, 'Kazu');
      expect(owner.displayName, 'Kazuki Mori');
      expect(owner.avatarUrl, isNull);
    });

    test('owner falls back to username when display_username missing', () async {
      final adapter = _Adapter(body: const {
        'items': [
          {
            'id': 'c1',
            'owner_id': 'u1',
            'name': 'A',
            'owner': {
              'id': 'u1',
              'username': 'kazu',
            },
          },
        ],
        'has_more': false,
      });
      final repo = PublicCollectionsRepository(_dio(adapter));

      final page = await repo.list();

      expect(page.items.first.owner.displayUsername, 'kazu');
    });
  });
}
