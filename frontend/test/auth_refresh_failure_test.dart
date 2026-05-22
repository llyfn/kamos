// KAMOS — Auth interceptor refresh-failure flow tests.
//
// When the refresh exchange itself fails (network error, 4xx, 5xx), the
// interceptor must:
//   1. clear BOTH access and refresh tokens from secure storage,
//   2. emit `ApiToastKind.unauthorized` on the toast bus,
//   3. invoke the `onAuthExpired` callback exactly once,
//   4. propagate the original 401 to the caller.

import 'dart:convert';

import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/api_toast.dart';
import 'package:kamos/core/api/auth_interceptor.dart';
import 'package:kamos/core/storage/secure_storage.dart';

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

class _AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'error': 'unauthorized', 'code': 'UNAUTHORIZED'}),
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test('failed refresh clears both tokens, fires toast, surfaces 401',
      () async {
    FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();
    final storage = SecureStorageService();
    await storage.writeToken('old-access');
    await storage.writeRefreshToken('refresh-1');

    var refreshCalls = 0;
    var authExpiredCalls = 0;
    final toasts = <ApiToastKind>[];

    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.test',
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ));
    dio.httpClientAdapter = _AlwaysUnauthorizedAdapter();
    final interceptor = AuthInterceptor(
      storage: storage,
      refreshExchange: (refreshToken) async {
        refreshCalls += 1;
        // Simulate the refresh endpoint itself rejecting the token.
        return const RefreshResult.failure();
      },
      onAuthExpired: () => authExpiredCalls += 1,
      onApiToast: toasts.add,
    );
    interceptor.retryDio = dio;
    dio.interceptors.add(interceptor);

    Object? caught;
    try {
      await dio.get<dynamic>('/v1/protected');
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<DioException>(),
        reason: 'the original 401 must propagate after refresh failure');
    expect((caught as DioException).response?.statusCode, 401);

    expect(refreshCalls, 1, reason: 'one refresh attempt');
    expect(authExpiredCalls, 1,
        reason: 'onAuthExpired fires exactly once on hard failure');
    expect(toasts, [ApiToastKind.unauthorized]);

    // Both tokens were wiped.
    expect(await storage.readToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });
}
