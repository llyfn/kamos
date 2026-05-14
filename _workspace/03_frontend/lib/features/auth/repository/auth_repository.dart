// KAMOS — AuthRepository. Talks to /v1/auth/* and persists the JWT pair on
// success.
//
// Phase 2 introduces rotating refresh tokens. `login`, `register`, `google`,
// and `refresh` all return a fresh pair; the access token expires in 15 min
// and the refresh token in 30 days by default. Both are persisted under
// `flutter_secure_storage` (never SharedPreferences — SPEC §6.9).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/auth.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  AuthRepository({required this.dio, required this.storage});
  final Dio dio;
  final SecureStorageService storage;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await dio.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _persist(auth);
    return auth;
  }

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
    String locale = 'en',
  }) async {
    final res = await dio.post(
      '/v1/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        'locale': locale,
      },
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _persist(auth);
    return auth;
  }

  Future<AuthResponse> google({
    required String idToken,
    String? username,
    String locale = 'en',
  }) async {
    final res = await dio.post(
      '/v1/auth/google',
      data: {
        'id_token': idToken,
        if (username != null && username.isNotEmpty) 'username': username,
        'locale': locale,
      },
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _persist(auth);
    return auth;
  }

  /// Exchanges the rotating refresh token for a new access/refresh pair.
  /// Persists the new pair on success.
  ///
  /// The interceptor calls this through a `Dio` instance that DOES NOT carry
  /// this interceptor (see `api_client.dart`) so that a 401 here can never
  /// recurse into another refresh attempt.
  Future<AuthResponse> refresh(String refreshToken) async {
    final res = await dio.post(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _persist(auth);
    return auth;
  }

  /// Best-effort server-side revocation. The endpoint is authed but tolerant —
  /// callers should treat any non-2xx as a no-op and proceed with the local
  /// cleanup. Omitting `refreshToken` asks the server to revoke ALL refresh
  /// tokens for the user.
  Future<void> logout({String? refreshToken}) async {
    try {
      await dio.post(
        '/v1/auth/logout',
        data: refreshToken != null && refreshToken.isNotEmpty
            ? {'refresh_token': refreshToken}
            : <String, dynamic>{},
      );
    } on DioException {
      // Ignore — server may be unreachable or the token may already be invalid.
      // Local token clearing is handled by the caller.
    }
  }

  Future<bool> verifyEmail(String token) async {
    final res = await dio.post(
      '/v1/auth/verify-email',
      data: {'token': token},
    );
    final body = res.data as Map<String, dynamic>;
    return (body['verified'] as bool?) ?? false;
  }

  Future<void> resendVerification() async {
    await dio.post('/v1/auth/resend-verification');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await dio.post(
      '/v1/auth/password-change',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<void> changeEmail(String newEmail) async {
    await dio.post(
      '/v1/auth/email-change',
      data: {'new_email': newEmail},
    );
  }

  Future<void> _persist(AuthResponse auth) async {
    await storage.writeToken(auth.accessToken);
    if (auth.refreshToken.isNotEmpty) {
      await storage.writeRefreshToken(auth.refreshToken);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.read(dioProvider),
    storage: ref.read(secureStorageProvider),
  ),
);
