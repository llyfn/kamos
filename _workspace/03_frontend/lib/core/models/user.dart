// KAMOS — User models (OpenAPI `User`, `Me`, `PublicProfile`).
//
// NOTE: per QA MINOR #8, `GET /v1/users/{username}` currently returns the
// public profile WITH the target user's email. The contract here mirrors the
// server, but the UI does NOT render email on a public profile — that field
// is treated as private metadata.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int checkins,
    @Default(0) int unique,
    @Default(0) int followers,
    @Default(0) int following,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        checkins: (json['checkins'] as int?) ?? 0,
        unique: (json['unique'] as int?) ?? 0,
        followers: (json['followers'] as int?) ?? 0,
        following: (json['following'] as int?) ?? 0,
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class User with _$User {
  const factory User({
    required String id,
    required String username,
    required String displayUsername,
    // Email may be absent or null on a public profile in some server builds.
    String? email,
    @Default(false) bool emailVerified,
    @Default('') String displayName,
    String? avatarUrl,
    String? bio,
    @Default('en') String locale,
    @Default('public') String privacyMode,
    @Default('') String createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        displayUsername:
            (json['display_username'] as String?) ?? (json['username'] as String? ?? ''),
        email: json['email'] as String?,
        emailVerified: (json['email_verified'] as bool?) ?? false,
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        locale: (json['locale'] as String?) ?? 'en',
        privacyMode: (json['privacy_mode'] as String?) ?? 'public',
        createdAt: (json['created_at'] as String?) ?? '',
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class Me with _$Me {
  const factory Me({
    required User user,
    required UserStats stats,
  }) = _Me;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        user: User.fromJson(json),
        stats: UserStats.fromJson(
          (json['stats'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class PublicProfile with _$PublicProfile {
  const factory PublicProfile({
    required User user,
    required UserStats stats,
    @Default('') String followState,
    @Default(false) bool restricted,
  }) = _PublicProfile;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        user: User.fromJson(json),
        stats: UserStats.fromJson(
          (json['stats'] as Map<String, dynamic>?) ?? const {},
        ),
        followState: (json['follow_state'] as String?) ?? '',
        restricted: (json['restricted'] as bool?) ?? false,
      );
}
