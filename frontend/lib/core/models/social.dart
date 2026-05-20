// KAMOS — Social models (OpenAPI `FollowRequest`, `FollowResult`, `SocialUser`).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'social.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class FollowRequest with _$FollowRequest {
  const factory FollowRequest({
    required String userId,
    required String username,
    required String displayUsername,
    required String displayName,
    String? avatarUrl,
    String? bio,
    @Default('') String createdAt,
  }) = _FollowRequest;

  factory FollowRequest.fromJson(Map<String, dynamic> json) => FollowRequest(
        userId: (json['user_id'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        displayUsername:
            (json['display_username'] as String?) ?? (json['username'] as String? ?? ''),
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        createdAt: (json['created_at'] as String?) ?? '',
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class FollowResult with _$FollowResult {
  const factory FollowResult({
    @Default('') String status,
  }) = _FollowResult;

  factory FollowResult.fromJson(Map<String, dynamic> json) =>
      FollowResult(status: (json['status'] as String?) ?? '');
}

@Freezed(fromJson: false, toJson: false)
abstract class SocialUser with _$SocialUser {
  const factory SocialUser({
    required String id,
    required String username,
    required String displayUsername,
    required String displayName,
    String? avatarUrl,
    @Default('') String followedAt,
  }) = _SocialUser;

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
        id: (json['id'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        displayUsername:
            (json['display_username'] as String?) ?? (json['username'] as String? ?? ''),
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        followedAt: (json['followed_at'] as String?) ?? '',
      );
}
