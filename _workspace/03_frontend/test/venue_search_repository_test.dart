// KAMOS — VenueRepository.search tests.
//
// Drives `GET /v1/venues/search` through a custom Dio adapter. Verifies:
// * 200 → list of FoursquarePlace, with q / lat / lng / locale forwarded.
// * 503 VENUE_SEARCH_DISABLED → throws VenueSearchDisabledException.
// * 503 VENUE_RATE_LIMITED   → throws VenueRateLimitedException.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/features/venues/repository/venue_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.status, required this.body});

  final int status;
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
  group('VenueRepository.search', () {
    test('200 returns parsed FoursquarePlace list and forwards query params',
        () async {
      final adapter = _Adapter(
        status: 200,
        body: const {
          'items': [
            {
              'foursquare_id': 'fsq-1',
              'name': 'Daikoku',
              'address': '1-2-3 Shibuya',
              'lat': 35.6595,
              'lng': 139.7005,
              'country': 'JP',
              'prefecture': 'Tokyo',
              'locality': 'Shibuya',
            },
            {
              'foursquare_id': 'fsq-2',
              'name': 'Sakura Bar',
              'lat': 35.6,
              'lng': 139.7,
            },
          ],
        },
      );
      final repo = VenueRepository(_dio(adapter));

      final results = await repo.search(
        query: 'daikoku',
        lat: 35.6595,
        lng: 139.7005,
        locale: 'ja',
      );

      expect(results, hasLength(2));
      expect(results.first.foursquareId, 'fsq-1');
      expect(results.first.name, 'Daikoku');
      expect(results.first.locality, 'Shibuya');
      expect(results.first.country, 'JP');
      expect(results.first.lat, closeTo(35.6595, 1e-6));

      final req = adapter.lastRequest!;
      expect(req.path, '/v1/venues/search');
      expect(req.queryParameters['q'], 'daikoku');
      expect(req.queryParameters['lat'], 35.6595);
      expect(req.queryParameters['lng'], 139.7005);
      expect(req.queryParameters['locale'], 'ja');
    });

    test('503 VENUE_SEARCH_DISABLED surfaces VenueSearchDisabledException',
        () async {
      final adapter = _Adapter(
        status: 503,
        body: const {
          'error': 'venue search not configured',
          'code': 'VENUE_SEARCH_DISABLED',
        },
      );
      final repo = VenueRepository(_dio(adapter));

      await expectLater(
        repo.search(query: 'daikoku'),
        throwsA(isA<VenueSearchDisabledException>()),
      );
    });

    test('503 VENUE_RATE_LIMITED surfaces VenueRateLimitedException',
        () async {
      final adapter = _Adapter(
        status: 503,
        body: const {
          'error': 'rate-limited upstream',
          'code': 'VENUE_RATE_LIMITED',
        },
      );
      final repo = VenueRepository(_dio(adapter));

      await expectLater(
        repo.search(query: 'daikoku'),
        throwsA(isA<VenueRateLimitedException>()),
      );
    });
  });
}
