// KAMOS — Comment model.
//
// Mirrors the OpenAPI `Comment` shape: a flat comment on a check-in. The
// `user` field reuses `CheckinUser` (the slim public-profile snapshot shape
// already used by `Checkin` and `FeedItem`), so a single avatar/username
// render path serves both surfaces.
//
// `deletedAt` is exposed for completeness but the server already filters
// soft-deleted comments out of the list response — clients never need to
// render a tombstone.
//
// Stage 7 (M-12.2): `user` is nullable. Migration 013 sets
// comments.user_id ON DELETE SET NULL, so a comment whose author was
// hard-purged by the username-hold sweep arrives with `user: null`. The
// tile renders the localized commentAuthorDeleted placeholder in that
// case.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';

part 'comment.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String checkInId,
    CheckinUser? user,
    required String body,
    @Default('') String createdAt,
    String? deletedAt,
    String? editedAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return Comment(
      id: (json['id'] as String?) ?? '',
      checkInId: (json['check_in_id'] as String?) ?? '',
      user: userJson is Map<String, dynamic>
          ? CheckinUser.fromJson(userJson)
          : null,
      body: (json['body'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      deletedAt: json['deleted_at'] as String?,
      editedAt: json['edited_at'] as String?,
    );
  }
}
