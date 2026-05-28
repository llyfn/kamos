// KAMOS — KamosApi smoke test.
//
// Asserts every tag's sub-API is non-null after construction, and that a
// representative call from each sub-facade hits the expected path. The
// adapter just echoes a benign 200 response — the goal is to verify path +
// verb wiring, not response decoding (which the per-repository tests cover).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/kamos_api.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Echo a body that satisfies the typical { items: [], has_more: false }
    // envelope AND a plain object — both shapes are tolerated by _asMap.
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'items': <dynamic>[], 'has_more': false}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

KamosApi _newApi(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.test',
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ))
    ..httpClientAdapter = adapter;
  return KamosApi(dio);
}

void main() {
  group('KamosApi construction', () {
    test('every sub-facade is non-null', () {
      final api = _newApi(_RecordingAdapter());
      expect(api.auth, isNotNull);
      expect(api.users, isNotNull);
      expect(api.beverages, isNotNull);
      expect(api.producers, isNotNull);
      expect(api.checkins, isNotNull);
      expect(api.comments, isNotNull);
      expect(api.collections, isNotNull);
      expect(api.feed, isNotNull);
      expect(api.social, isNotNull);
      expect(api.search, isNotNull);
      expect(api.taxonomy, isNotNull);
      expect(api.venues, isNotNull);
      expect(api.uploads, isNotNull);
      expect(api.beverageRequests, isNotNull);
      expect(api.notifications, isNotNull);
    });
  });

  group('KamosApi path wiring (spot check per tag)', () {
    test('auth.login → POST /v1/auth/login', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.auth.login(email: 'a@b.c', password: 'x');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/v1/auth/login');
    });

    test('users.getMe → GET /v1/users/me', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.users.getMe();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/v1/users/me');
    });

    test('beverages.get → GET /v1/beverages/{id}', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.beverages.get('bev-1');
      expect(adapter.requests.single.path, '/v1/beverages/bev-1');
    });

    test('producers.get → GET /v1/producers/{id}', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.producers.get('br-1');
      expect(adapter.requests.single.path, '/v1/producers/br-1');
    });

    test('checkins.toggleToast → POST /v1/check-ins/{id}/toast', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.checkins.toggleToast('ci-1');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/v1/check-ins/ci-1/toast');
    });

    test('comments.list → GET /v1/check-ins/{id}/comments', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.comments.list('ci-1');
      expect(adapter.requests.single.path, '/v1/check-ins/ci-1/comments');
    });

    test('collections.detail → GET /v1/collections/{id}', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.collections.detail('col-1');
      expect(adapter.requests.single.path, '/v1/collections/col-1');
    });

    test('feed.getFeed → GET /v1/feed?limit=20', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.feed.getFeed();
      final r = adapter.requests.single;
      expect(r.path, '/v1/feed');
      expect(r.queryParameters['limit'], 20);
    });

    test('social.follow → POST /v1/users/{username}/follow', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.social.follow('mai');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/v1/users/mai/follow');
    });

    test('search.query → GET /v1/search?q=...', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.search.query(q: 'dassai');
      final r = adapter.requests.single;
      expect(r.path, '/v1/search');
      expect(r.queryParameters['q'], 'dassai');
    });

    test('taxonomy.categories → GET /v1/categories', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.taxonomy.categories();
      expect(adapter.requests.single.path, '/v1/categories');
    });

    test('venues.search → GET /v1/venues/search?q=...', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.venues.search(query: 'kanazawa', lat: 36.5, lng: 136.6);
      final r = adapter.requests.single;
      expect(r.path, '/v1/venues/search');
      expect(r.queryParameters['q'], 'kanazawa');
      expect(r.queryParameters['lat'], 36.5);
      expect(r.queryParameters['lng'], 136.6);
    });

    test('uploads.presignPhotoUpload → POST /v1/uploads/photo-presign',
        () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.uploads.presignPhotoUpload(
        contentType: 'image/jpeg',
        byteSize: 2048,
      );
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/v1/uploads/photo-presign');
    });

    test('beverageRequests.submit → POST /v1/beverage-requests', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.beverageRequests.submit({'payload': <String, dynamic>{}});
      expect(adapter.requests.single.path, '/v1/beverage-requests');
    });

    test('notifications.list → GET /v1/notifications?limit=20', () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.notifications.list();
      final r = adapter.requests.single;
      expect(r.method, 'GET');
      expect(r.path, '/v1/notifications');
      expect(r.queryParameters['limit'], 20);
    });

    test('notifications.unreadCount → GET /v1/notifications/unread-count',
        () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.notifications.unreadCount();
      final r = adapter.requests.single;
      expect(r.method, 'GET');
      expect(r.path, '/v1/notifications/unread-count');
    });

    test('notifications.markRead ids → POST /v1/notifications/read with ids',
        () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.notifications.markRead(ids: ['n1', 'n2']);
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/v1/notifications/read');
      expect(r.data, {'ids': ['n1', 'n2']});
    });

    test('notifications.markRead all → POST /v1/notifications/read with all',
        () async {
      final adapter = _RecordingAdapter();
      final api = _newApi(adapter);
      await api.notifications.markRead(all: true);
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/v1/notifications/read');
      expect(r.data, {'all': true});
    });
  });
}
