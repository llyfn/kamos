// KAMOS — Comment model (Phase 6).
//
// Mirrors the OpenAPI `Comment` shape: a flat comment on a check-in. The
// `user` field reuses `CheckinUser` (the slim public-profile snapshot shape
// already used by `Checkin` and `FeedItem`), so a single avatar/username
// render path serves both surfaces.
//
// `deletedAt` is exposed for completeness but the server already filters
// soft-deleted comments out of the list response — clients never need to
// render a tombstone.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';

part 'comment.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String checkInId,
    required CheckinUser user,
    required String body,
    @Default('') String createdAt,
    String? deletedAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: (json['id'] as String?) ?? '',
        checkInId: (json['check_in_id'] as String?) ?? '',
        user: CheckinUser.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
        body: (json['body'] as String?) ?? '',
        createdAt: (json['created_at'] as String?) ?? '',
        deletedAt: json['deleted_at'] as String?,
      );
}
