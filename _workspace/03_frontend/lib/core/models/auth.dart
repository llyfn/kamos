// KAMOS — Auth request/response models.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth.freezed.dart';

@Freezed(fromJson: false, toJson: false)
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required User user,
    required String accessToken,
    required String tokenType,
    required int expiresIn,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: User.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
        accessToken: (json['access_token'] as String?) ?? '',
        tokenType: (json['token_type'] as String?) ?? 'Bearer',
        expiresIn: (json['expires_in'] as int?) ?? 0,
      );
}
