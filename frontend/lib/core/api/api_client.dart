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

import '../../features/auth/providers/auth_state.dart';
import '../auth/jwt_claims.dart';
import '../models/auth.dart';
import '../storage/secure_storage.dart';
import 'api_config.dart';
import 'api_toast.dart';
import 'auth_interceptor.dart';

/// HTTP cache contract for the authed Dio singleton.
///
/// Cached on the client (via `dio_cache_interceptor`):
///
/// EVERY authenticated GET response is eligible for caching when the
/// server returns a `Cache-Control` directive AND an `ETag`. The server
/// currently mounts `ETag` globally on all GET routes (see
/// `backend/internal/server/router.go`).
///
/// Concrete cached routes today (per server `Cache-Control` max-age):
///   - GET /v1/categories                    (max-age=3600, public)
///   - GET /v1/flavor-tags                   (max-age=3600, public)
///   - GET /v1/beverages/{id}                (max-age=300, public)
///   - GET /v1/producers/{id}                (max-age=600, public)
///   - GET /v1/users/{username}              (private, must-revalidate)
///
/// All other authenticated GETs get only the ETag round-trip — they
/// always revalidate against the server (no offline cache hit) because
/// the server emits `Cache-Control: no-cache` or omits the directive.
///
/// Never cached: all `/v1/auth/*`, all POST/PATCH/DELETE.
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
/// Privacy: the cache key includes the JWT `sub` claim (see keyBuilder
/// in [_buildCacheOptions]) so two users sharing a device cannot see
/// each other's cached responses, even offline.
///
/// To force a single request to bypass the cache (e.g. a "pull to refresh"),
/// pass `Options(extra: kBypassCache)` from `cache_extras.dart`.

/// Cache key that folds the current user's JWT `sub` claim into the URL.
///
/// `dio_cache_interceptor`'s default builder UUID-v5-hashes the URL only,
/// which means two users on the same device share a cache namespace. That is
/// safe on the wire (the server's body-derived ETag + `must-revalidate`
/// directive forces a fresh fetch on viewer change) but unsafe offline,
/// because `hitCacheOnNetworkFailure: true` serves the previous viewer's
/// cached body without revalidation.
///
/// This builder prepends `<sub>|` (or `anon|` when no token is active) to the
/// URL string before invoking the underlying hash, namespacing User A's and
/// User B's entries from birth. The result is a stable, opaque string —
/// shape matches what `CacheOptions.defaultCacheKeyBuilder` returns, so the
/// downstream `CacheStore` API is unaffected.
///
/// Signature verification is intentionally NOT performed here — every
/// authenticated request is verified server-side; the client only needs a
/// stable per-user discriminator. A tampered token would simply map to a
/// different namespace, never to another user's data.
String cacheKeyBuilder({
  required Uri url,
  Map<String, String>? headers,
  Object? body,
}) {
  // Stage 5 (PERF-018): the JWT `sub` is memoized inside
  // SecureStorageService so the keyBuilder doesn't pay the base64 +
  // JSON parse cost on every request. The memo invalidates whenever
  // the active token changes.
  final uid =
      SecureStorageService.currentSubMemoized(decodeUserIdFromJwt) ?? 'anon';
  // The default builder accepts a Uri, but we want to fold a non-URL
  // discriminator in. Hash via the same SHA-1-based pathway by stuffing the
  // discriminator into the URL fragment, which is a legal Uri component and
  // is included in `toString()`.
  final namespaced = url.replace(
    fragment: '${url.fragment.isEmpty ? '' : '${url.fragment};'}kamos-uid=$uid',
  );
  return CacheOptions.defaultCacheKeyBuilder(
    url: namespaced,
    headers: headers,
    body: body,
  );
}

CacheOptions _buildCacheOptions() {
  return CacheOptions(
    // In-memory store, 5 MB cap (LRU eviction). sticks to in-memory
    // to avoid the platform-specific filesystem code path; a Hive-backed
    // store can land later if offline reads become a requirement.
    store: MemCacheStore(maxSize: 5 * 1024 * 1024),
    policy: CachePolicy.request,
    hitCacheOnErrorCodes: const [],
    hitCacheOnNetworkFailure: true,
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
    keyBuilder: cacheKeyBuilder,
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
        final res = await refreshDio.post<Map<String, dynamic>>(
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
