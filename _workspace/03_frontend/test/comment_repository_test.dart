// KAMOS — CommentRepository tests (Phase 6).
//
// Drives the three comment endpoints through a custom Dio adapter:
// * GET    /v1/check-ins/{id}/comments → parsed list (accepts both `items`
//   envelope and a bare array).
// * POST   /v1/check-ins/{id}/comments → body sent + parsed comment returned.
// * POST   with >500 char body → CommentTooLongException, no request.
// * DELETE /v1/comments/{id} on 403 → CommentForbiddenException.
// * DELETE /v1/comments/{id} on 404 → CommentDeletedException.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/features/comments/exceptions.dart';
import 'package:kamos/features/comments/repository/comment_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.status, required this.body});

  final int status;
  final dynamic body;

  RequestOptions? lastRequest;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
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
  group('CommentRepository.list', () {
    test('parses {"items":[...]} envelope', () async {
      final adapter = _Adapter(status: 200, body: const {
        'items': [
          {
            'id': 'cm1',
            'check_in_id': 'ci42',
            'user': {'id': 'u1', 'username': 'mai'},
            'body': 'Yum.',
            'created_at': '2026-05-01T00:00:00Z',
          },
        ],
      });
      final repo = CommentRepository(_dio(adapter));

      final results = await repo.list('ci42');

      expect(results, hasLength(1));
      expect(results.first.id, 'cm1');
      expect(results.first.body, 'Yum.');
      expect(adapter.lastRequest!.path, '/v1/check-ins/ci42/comments');
    });

    test('parses a bare top-level array', () async {
      final adapter = _Adapter(status: 200, body: const [
        {
          'id': 'cm1',
          'body': 'a',
        },
        {
          'id': 'cm2',
          'body': 'b',
        },
      ]);
      final repo = CommentRepository(_dio(adapter));

      final results = await repo.list('ci42');

      expect(results, hasLength(2));
    });
  });

  group('CommentRepository.create', () {
    test('200 returns parsed comment and sends `body` in the request',
        () async {
      final adapter = _Adapter(status: 200, body: const {
        'id': 'cm-new',
        'check_in_id': 'ci42',
        'user': {'id': 'u1', 'username': 'mai'},
        'body': 'Posted.',
        'created_at': '2026-05-02T00:00:00Z',
      });
      final repo = CommentRepository(_dio(adapter));

      final c = await repo.create(checkInId: 'ci42', body: 'Posted.');

      expect(c.id, 'cm-new');
      expect(c.body, 'Posted.');
      final req = adapter.lastRequest!;
      expect(req.method, 'POST');
      expect(req.path, '/v1/check-ins/ci42/comments');
      expect(req.data, {'body': 'Posted.'});
    });

    test('>500 chars throws CommentTooLongException without a request',
        () async {
      final adapter = _Adapter(status: 200, body: const {});
      final repo = CommentRepository(_dio(adapter));
      final tooLong = List<String>.filled(501, 'x').join();

      await expectLater(
        repo.create(checkInId: 'ci42', body: tooLong),
        throwsA(isA<CommentTooLongException>()),
      );
      expect(adapter.calls, 0);
    });
  });

  group('CommentRepository.deleteOwn', () {
    test('204 success path returns normally', () async {
      final adapter = _Adapter(status: 204, body: const <String, dynamic>{});
      final repo = CommentRepository(_dio(adapter));

      await repo.deleteOwn('cm1');

      final req = adapter.lastRequest!;
      expect(req.method, 'DELETE');
      expect(req.path, '/v1/comments/cm1');
    });

    test('403 surfaces CommentForbiddenException', () async {
      final adapter =
          _Adapter(status: 403, body: const {'error': 'not yours'});
      final repo = CommentRepository(_dio(adapter));

      await expectLater(
        repo.deleteOwn('cm1'),
        throwsA(isA<CommentForbiddenException>()),
      );
    });

    test('404 surfaces CommentDeletedException', () async {
      final adapter =
          _Adapter(status: 404, body: const {'error': 'gone'});
      final repo = CommentRepository(_dio(adapter));

      await expectLater(
        repo.deleteOwn('cm1'),
        throwsA(isA<CommentDeletedException>()),
      );
    });
  });
}
