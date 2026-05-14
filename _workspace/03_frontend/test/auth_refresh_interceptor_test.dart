// KAMOS — Auth interceptor refresh-token flow tests.
//
// These exercise the `AuthInterceptor` directly with a `MockAdapter`-backed
// Dio. The adapter answers `/v1/protected` with 401 once, then 200; the
// interceptor must swap the refresh token, then retry the original request
// with the new access token.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/auth_interceptor.dart';
import 'package:kamos/core/api/api_toast.dart';
import 'package:kamos/core/storage/secure_storage.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory FlutterSecureStorage substitute. Backs all reads/writes on a
/// `Map` so tests need no platform channel.
class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _values.containsKey(key);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      _values[key];

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      Map<String, String>.from(_values);

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    _values[key] = value;
  }
}

/// Adapter that answers `/v1/protected` based on the bearer token. The first
/// call (with `old-access`) returns 401; any other token returns 200. Tracks
/// how many times each was called.
class _ProtectedAdapter implements HttpClientAdapter {
  int requestsWithOld = 0;
  int requestsWithNew = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    if (options.path.endsWith('/v1/protected')) {
      if (auth == 'Bearer old-access') {
        requestsWithOld += 1;
        return ResponseBody.fromString(
          jsonEncode({'error': 'unauthorized', 'code': 'UNAUTHORIZED'}),
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      requestsWithNew += 1;
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('not found', 404);
  }
}

void main() {
  group('AuthInterceptor refresh loop', () {
    late SecureStorageService storage;
    late _ProtectedAdapter adapter;
    late int refreshCalls;
    late int authExpiredCalls;
    late List<ApiToastKind> toasts;
    late Dio dio;

    setUp(() async {
      FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();
      storage = SecureStorageService();
      await storage.writeToken('old-access');
      await storage.writeRefreshToken('refresh-1');

      adapter = _ProtectedAdapter();
      refreshCalls = 0;
      authExpiredCalls = 0;
      toasts = [];

      dio = Dio(BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (s) => s != null && s >= 200 && s < 300,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ));
      dio.httpClientAdapter = adapter;
      final interceptor = AuthInterceptor(
        storage: storage,
        refreshExchange: (refreshToken) async {
          refreshCalls += 1;
          // Mimic AuthRepository.refresh persisting through the storage
          // facade.
          await storage.writeToken('new-access');
          await storage.writeRefreshToken('refresh-2');
          return const RefreshResult.success('new-access', 'refresh-2');
        },
        onAuthExpired: () => authExpiredCalls += 1,
        onApiToast: toasts.add,
      );
      interceptor.retryDio = dio;
      dio.interceptors.add(interceptor);
    });

    test(
        '401 on protected route triggers exactly one refresh and one retry with new token',
        () async {
      final res = await dio.get<dynamic>('/v1/protected');

      expect(res.statusCode, 200);
      expect(refreshCalls, 1, reason: 'refresh exchanged exactly once');
      expect(adapter.requestsWithOld, 1,
          reason: 'the first attempt used the stale token');
      expect(adapter.requestsWithNew, 1,
          reason: 'the retry used the freshly-issued token');
      expect(authExpiredCalls, 0,
          reason: 'refresh succeeded — no auth-expired callback');
      expect(toasts, isEmpty,
          reason: 'happy-path refresh does not surface a toast');

      // Storage now holds the rotated pair.
      expect(await storage.readToken(), 'new-access');
      expect(await storage.readRefreshToken(), 'refresh-2');
    });
  });
}
