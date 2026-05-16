// KAMOS — Dio client providers.
//
// Two Dio instances live behind two providers:
//
// * `dioProvider` — installed with `AuthInterceptor`. Used by every
//   repository (feed, beverage, profile, …) AND by `AuthRepository` itself
//   for login/register/google/verify-email. The interceptor attaches the
//   access token, surfaces 401/network toasts, and runs the refresh loop
//   on 401.
//
// * `refreshDioProvider` — a bare Dio with no `AuthInterceptor`. The
//   interceptor's refresh callback uses this client when it POSTs to
//   `/v1/auth/refresh`, so a refresh 401 cannot recurse into another
//   refresh attempt.

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/providers/auth_state.dart';
import 'api_config.dart';
import 'api_toast.dart';
import 'auth_interceptor.dart';

/// HTTP cache contract for the authed Dio singleton (Phase 7).
///
/// Cached on the client (server emits `Cache-Control: max-age=...` + `ETag`):
///   * `GET /v1/categories`
///   * `GET /v1/flavor-tags`
///   * `GET /v1/beverages/{id}`
///   * `GET /v1/breweries/{id}`
///   * `GET /v1/users/{username}`
///
/// Never cached (server emits `Cache-Control: no-store` or `private`, or the
/// request is a mutation):
///   * Everything under `/v1/auth/*`
///   * Any `POST` / `PATCH` / `DELETE` (dio_cache_interceptor v4 excludes
///     non-GET by default — `allowPostMethod: false` keeps that contract
///     explicit)
///   * The feed (`GET /v1/feed`) and any other endpoint that mutates as the
///     viewer changes
///
/// Policy is `CachePolicy.request` — return the cached value if it is still
/// fresh per the server's `Cache-Control: max-age` directive, otherwise
/// revalidate with the origin (sending `If-None-Match` on the stored ETag).
/// This is the package's "respect what the server says" default and the
/// closest analogue to HTTP's standard cache semantics.
///
/// `hitCacheOnNetworkFailure: true` lets the client serve a stale body when
/// the network is unreachable (connect/send/receive timeout, socket error).
/// `hitCacheOnErrorCodes` stays empty, so a 401 or 403 from the server is NOT
/// swallowed by the cache layer — those still reach `AuthInterceptor` and the
/// refresh-token dance fires as usual.
///
/// `allowPostMethod: false` keeps the contract explicit even though POST is
/// not cached by default in v4: mutating verbs never see the cache.
///
/// To force a single request to bypass the cache (e.g. a "pull to refresh"),
/// pass `Options(extra: kBypassCache)` from `cache_extras.dart`.
CacheOptions _buildCacheOptions() {
  return CacheOptions(
    // In-memory store, 5 MB cap (LRU eviction). Phase 7 sticks to in-memory
    // to avoid the platform-specific filesystem code path; a Hive-backed
    // store can land later if offline reads become a requirement.
    store: MemCacheStore(maxSize: 5 * 1024 * 1024),
    policy: CachePolicy.request,
    hitCacheOnErrorCodes: const [],
    hitCacheOnNetworkFailure: true,
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );
}

/// Naked Dio used by the refresh exchange so a refresh-call 401 cannot recurse
/// back into the interceptor's refresh path.
final refreshDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (s) => s != null && s >= 200 && s < 300,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      // Treat 4xx/5xx as Dio errors so the interceptor can normalise them.
      validateStatus: (s) => s != null && s >= 200 && s < 300,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  final storage = ref.read(secureStorageProvider);
  final refreshDio = ref.read(refreshDioProvider);

  final interceptor = AuthInterceptor(
    storage: storage,
    refreshExchange: (refreshToken) async {
      try {
        final res = await refreshDio.post(
          '/v1/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
        // Persist through the same storage facade so SecureStorageService
        // remains the only writer (SPEC §6.9).
        await storage.writeToken(auth.accessToken);
        if (auth.refreshToken.isNotEmpty) {
          await storage.writeRefreshToken(auth.refreshToken);
        }
        return RefreshResult.success(
          auth.accessToken,
          auth.refreshToken.isEmpty ? refreshToken : auth.refreshToken,
        );
      } catch (_) {
        return const RefreshResult.failure();
      }
    },
    onAuthExpired: () {
      // The auth controller observes the token; calling onUnauthorized()
      // flips state to unauthenticated and the router redirects.
      ref.read(authStateProvider.notifier).onUnauthorized();
    },
    onApiToast: (kind) {
      ref.read(apiToastBusProvider.notifier).emit(kind);
    },
  );
  interceptor.retryDio = dio;
  // Order matters. `DioCacheInterceptor` is registered FIRST so a cache hit
  // short-circuits in `onRequest` via `handler.resolve(...)` BEFORE
  // `AuthInterceptor` runs — a cached 200 must never trigger the 401-retry-
  // refresh path. For network responses (cache miss / stale), Dio walks
  // interceptors in reverse for `onResponse`/`onError`, so `AuthInterceptor`
  // still sees real auth failures and can refresh as usual.
  dio.interceptors.add(DioCacheInterceptor(options: _buildCacheOptions()));
  dio.interceptors.add(interceptor);

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        request: false,
        requestHeader: false,
        responseHeader: false,
        error: true,
      ),
    );
  }

  return dio;
});
