// KAMOS — Dio client provider.
//
// Repositories depend on this provider, never on Dio directly via the global
// constructor. Auth interceptor is wired in here so the same token-management
// rules apply to every request.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import '../../features/auth/providers/auth_state.dart';
import 'api_config.dart';
import 'api_toast.dart';
import 'auth_interceptor.dart';

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

  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.read(secureStorageProvider),
      onAuthExpired: () {
        // The auth controller observes the token; calling logout() also
        // invalidates dependent providers.
        ref.read(authStateProvider.notifier).onUnauthorized();
      },
      onApiToast: (kind) {
        ref.read(apiToastBusProvider.notifier).emit(kind);
      },
    ),
  );

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
