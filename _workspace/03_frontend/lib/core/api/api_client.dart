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
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/providers/auth_state.dart';
import 'api_config.dart';
import 'api_toast.dart';
import 'auth_interceptor.dart';

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
