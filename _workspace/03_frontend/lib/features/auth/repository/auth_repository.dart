// KAMOS — AuthRepository. Talks to /v1/auth/* and persists the JWT on
// success.

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
    final body = res.data as Map<String, dynamic>;
    final auth = AuthResponse.fromJson(body);
    await storage.writeToken(auth.accessToken);
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
    final body = res.data as Map<String, dynamic>;
    final auth = AuthResponse.fromJson(body);
    await storage.writeToken(auth.accessToken);
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
    final body = res.data as Map<String, dynamic>;
    final auth = AuthResponse.fromJson(body);
    await storage.writeToken(auth.accessToken);
    return auth;
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
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.read(dioProvider),
    storage: ref.read(secureStorageProvider),
  ),
);
