// KAMOS — Auth request/response models.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required User user,
    required String accessToken,
    required String refreshToken,
    required String tokenType,
    required int expiresIn,
    required int refreshExpiresIn,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: User.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
        accessToken: (json['access_token'] as String?) ?? '',
        // Phase 2 backend introduces rotating refresh tokens. Older responses
        // (or stub data) without the field decode as an empty string; callers
        // treat that as "no refresh available" and fall back to single-token
        // semantics.
        refreshToken: (json['refresh_token'] as String?) ?? '',
        tokenType: (json['token_type'] as String?) ?? 'Bearer',
        expiresIn: (json['expires_in'] as int?) ?? 0,
        refreshExpiresIn: (json['refresh_expires_in'] as int?) ?? 0,
      );
}
