// KAMOS — Phase 7 HTTP cache + ETag tests.
//
// Verifies the `DioCacheInterceptor` round-trip end-to-end against a
// `MockAdapter`-backed Dio that mimics the backend's
// `Cache-Control: public, max-age=N` + `ETag: "..."` response for read-heavy
// endpoints (`/v1/categories`, etc., see api_client.dart for the full list).
//
// Three behaviours are exercised:
//   1. The fresh GET fills the cache.
//   2. A second GET within `max-age` is served from cache without hitting
//      the adapter (network call count stays at 1).
//   3. After `max-age` expires, the next GET sends `If-None-Match: "<etag>"`
//      and on `304 Not Modified` the interceptor returns the cached body.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter that mimics a `/v1/categories`-style endpoint:
///   * Tracks how many real network calls landed.
///   * Records the `If-None-Match` header it saw on each call.
///   * The first call (no `If-None-Match`) returns 200 + Cache-Control +
///     ETag. Subsequent calls bearing the matching `If-None-Match` return
///     `304 Not Modified` (no body, ETag echoed). Subsequent calls without
///     the matching header return another full 200.
class _CategoriesAdapter implements HttpClientAdapter {
  _CategoriesAdapter({required this.maxAge, required this.etag});

  final int maxAge;
  final String etag;

  int totalRequests = 0;
  final List<String?> inboundIfNoneMatch = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    totalRequests += 1;
    final ifNoneMatch = options.headers['if-none-match'] as String? ??
        options.headers['If-None-Match'] as String?;
    inboundIfNoneMatch.add(ifNoneMatch);

    if (ifNoneMatch != null && ifNoneMatch == etag) {
      return ResponseBody.fromString(
        '',
        304,
        headers: {
          'cache-control': ['public, max-age=$maxAge'],
          'etag': [etag],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'items': [
          {'id': 'cat-sake', 'name': 'Nihonshu (Sake)'},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'cache-control': ['public, max-age=$maxAge'],
        'etag': [etag],
      },
    );
  }
}

Dio _buildCachedDio({
  required _CategoriesAdapter adapter,
  required CacheStore store,
  Duration maxStale = const Duration(days: 7),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test',
      // Treat anything 2xx/3xx as success so the cache interceptor sees the
      // 304 response (Dio would otherwise raise it as an error).
      validateStatus: (s) => s != null && s >= 200 && s < 400,
    ),
  );
  final options = CacheOptions(
    store: store,
    // `request` is the v4 default: returns cached value when fresh per the
    // server's Cache-Control directive, otherwise revalidates with the
    // origin (sending If-None-Match) — this is what we want to assert.
    policy: CachePolicy.request,
    hitCacheOnErrorCodes: const [],
    hitCacheOnNetworkFailure: true,
    maxStale: maxStale,
    priority: CachePriority.normal,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );
  dio.interceptors.add(DioCacheInterceptor(options: options));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('DioCacheInterceptor end-to-end', () {
    test(
        'second GET within max-age is served from cache without hitting the '
        'network', () async {
      final adapter = _CategoriesAdapter(maxAge: 300, etag: '"abc"');
      final store = MemCacheStore();
      final dio = _buildCachedDio(adapter: adapter, store: store);

      final first = await dio.get<Map<String, dynamic>>('/v1/categories');
      expect(first.statusCode, 200);
      expect(first.data, isA<Map<String, dynamic>>());
      expect(adapter.totalRequests, 1);

      final second = await dio.get<Map<String, dynamic>>('/v1/categories');
      expect(second.statusCode, 200);
      expect(second.data, isA<Map<String, dynamic>>());
      // Cache hit — adapter not called a second time.
      expect(adapter.totalRequests, 1);
    });

    test(
        'when the cached entry is stale, the next GET sends If-None-Match '
        'and a 304 returns the cached body', () async {
      // `max-age: 0` makes the cache entry immediately stale, which is the
      // deterministic equivalent of waiting for the freshness window to
      // elapse. The interceptor's CacheStrategy then attaches
      // `If-None-Match` from the stored ETag (see http_cache_core
      // `cache_strategy.dart:112`), the adapter returns 304, and the
      // interceptor reconstructs the original 200 body for the caller.
      final adapter = _CategoriesAdapter(maxAge: 0, etag: '"abc"');
      final store = MemCacheStore();
      final dio = _buildCachedDio(adapter: adapter, store: store);

      // First call — fresh body stored with ETag.
      final first = await dio.get<Map<String, dynamic>>('/v1/categories');
      expect(first.statusCode, 200);
      expect(adapter.totalRequests, 1);
      expect(adapter.inboundIfNoneMatch.first, isNull);

      // Second call — cache entry is stale (max-age=0) so the interceptor
      // revalidates rather than serving from cache.
      final second = await dio.get<Map<String, dynamic>>('/v1/categories');
      expect(adapter.totalRequests, 2);
      expect(adapter.inboundIfNoneMatch.last, '"abc"');
      // 304 on the wire, but the caller sees the original 200 body — the
      // interceptor reconstructs the response from cache.
      expect(second.data, isA<Map<String, dynamic>>());
      expect(second.data!['items'], isA<List<dynamic>>());
    });
  });
}
