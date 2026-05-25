// KAMOS — PublicUser model (OpenAPI `PublicUser`).
//
// Privacy-safe projection returned by `GET /v1/users/search` and elsewhere.
// `email` / `email_verified` are intentionally absent — they are owner-only
// and only surface on `/v1/users/me`.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_user.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class PublicUser with _$PublicUser {
  const factory PublicUser({
    required String id,
    required String username,
    required String displayUsername,
    @Default('') String displayName,
    String? avatarUrl,
    String? bio,
    @Default('en') String locale,
    @Default('public') String privacyMode,
    @Default('') String createdAt,
  }) = _PublicUser;

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
    id: (json['id'] as String?) ?? '',
    username: (json['username'] as String?) ?? '',
    displayUsername:
        (json['display_username'] as String?) ??
        (json['username'] as String? ?? ''),
    displayName: (json['display_name'] as String?) ?? '',
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    locale: (json['locale'] as String?) ?? 'en',
    privacyMode: (json['privacy_mode'] as String?) ?? 'public',
    createdAt: (json['created_at'] as String?) ?? '',
  );
}
