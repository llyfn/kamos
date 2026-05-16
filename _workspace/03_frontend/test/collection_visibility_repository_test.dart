// KAMOS — CollectionRepository.updateVisibility tests (Phase 6).
//
// Drives `PATCH /v1/collections/{id}` through a custom Dio adapter. Verifies:
// * Sending `public` → request body `{"visibility":"public"}`.
// * Sending `private` → request body `{"visibility":"private"}`.
// * Parsed response carries the new `visibility` value.
// * `Collection.fromJson` without a `visibility` key defaults to `private`
//   (backward-compat with older servers).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/collection.dart';
import 'package:kamos/features/collections/repository/collection_repository.dart';

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
  group('Collection.fromJson visibility default', () {
    test('missing visibility key → CollectionVisibility.private', () {
      final c = Collection.fromJson(const {
        'id': 'c1',
        'name': 'Inventory',
        'entry_count': 3,
      });
      expect(c.visibility, CollectionVisibility.private);
    });

    test('visibility: "public" → CollectionVisibility.public', () {
      final c = Collection.fromJson(const {
        'id': 'c1',
        'name': 'Faves',
        'visibility': 'public',
      });
      expect(c.visibility, CollectionVisibility.public);
    });

    test('unknown visibility string falls back to private', () {
      final c = Collection.fromJson(const {
        'id': 'c1',
        'name': 'Faves',
        'visibility': 'something-weird',
      });
      expect(c.visibility, CollectionVisibility.private);
    });
  });

  group('CollectionRepository.updateVisibility', () {
    test('toggling to public PATCHes {"visibility":"public"}', () async {
      final adapter = _Adapter(body: const {
        'id': 'c1',
        'name': 'Inventory',
        'visibility': 'public',
      });
      final repo = CollectionRepository(dio: _dio(adapter));

      final result =
          await repo.updateVisibility('c1', CollectionVisibility.public);

      expect(result.visibility, CollectionVisibility.public);
      final req = adapter.lastRequest!;
      expect(req.method, 'PATCH');
      expect(req.path, '/v1/collections/c1');
      expect(req.data, {'visibility': 'public'});
    });

    test('toggling to private PATCHes {"visibility":"private"}', () async {
      final adapter = _Adapter(body: const {
        'id': 'c1',
        'name': 'Inventory',
        'visibility': 'private',
      });
      final repo = CollectionRepository(dio: _dio(adapter));

      final result =
          await repo.updateVisibility('c1', CollectionVisibility.private);

      expect(result.visibility, CollectionVisibility.private);
      final req = adapter.lastRequest!;
      expect(req.data, {'visibility': 'private'});
    });
  });
}
