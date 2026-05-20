// KAMOS — FeedRepository.getFeed forceRefresh wiring test.
//
// Verifies that passing `forceRefresh: true` decorates the outgoing Dio
// request with the `kBypassCache` extras, so the global `DioCacheInterceptor`
// (mounted on the authed Dio in `api_client.dart`) will skip its in-memory
// cache for that call. The default (no flag) must NOT carry the bypass.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/cache_extras.dart';
import 'package:kamos/features/feed/repository/feed_repository.dart';

// Mirrors the extras key defined in dio_cache_interceptor's
// `cache_option_extension.dart` (private to the package — re-declared here so
// we can assert on what the repository attached without depending on internal
// symbols).
const _extraKey = '@cache_options@';

/// Captures the outgoing `RequestOptions.extra` for each call so the test can
/// assert how `getFeed` decorated the request. Returns an empty page envelope.
class _CapturingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> capturedExtras = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedExtras.add(Map<String, dynamic>.from(options.extra));
    return ResponseBody.fromString(
      jsonEncode({
        'items': <Map<String, dynamic>>[],
        'next_cursor': null,
        'has_more': false,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  group('FeedRepository.getFeed forceRefresh', () {
    test(
        'forceRefresh: true attaches the kBypassCache extras with policy = noCache',
        () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repo = FeedRepository(dio: dio);

      await repo.getFeed(forceRefresh: true);

      expect(adapter.capturedExtras, hasLength(1));
      final extra = adapter.capturedExtras.single;
      expect(
        extra.containsKey(_extraKey),
        isTrue,
        reason:
            'forceRefresh: true must merge kBypassCache into Options.extra so '
            'DioCacheInterceptor sees the noCache policy on this request.',
      );
      final cacheOptions = extra[_extraKey];
      expect(cacheOptions, isA<CacheOptions>());
      expect((cacheOptions as CacheOptions).policy, CachePolicy.noCache);

      // Defensive: the global kBypassCache map must surface the same value
      // here — guards against the repository accidentally rebuilding the map
      // with different semantics.
      expect(kBypassCache[_extraKey], isA<CacheOptions>());
      expect(
        (kBypassCache[_extraKey] as CacheOptions).policy,
        CachePolicy.noCache,
      );
    });

    test('default call (forceRefresh: false) does NOT attach the bypass extras',
        () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repo = FeedRepository(dio: dio);

      await repo.getFeed();

      expect(adapter.capturedExtras, hasLength(1));
      expect(
        adapter.capturedExtras.single.containsKey(_extraKey),
        isFalse,
        reason:
            'A normal feed fetch must not opt out of the cache — only the '
            'pull-to-refresh path should bypass it.',
      );
    });
  });
}
