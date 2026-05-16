// KAMOS — Collection models (OpenAPI `Collection`, `CollectionEntry`).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';

part 'collection.freezed.dart';

/// Collection visibility (Phase 6). `private` is the default for backward
/// compatibility with older servers that don't emit the field.
enum CollectionVisibility { private, public }

extension CollectionVisibilityParse on CollectionVisibility {
  static CollectionVisibility fromWire(String? s) => switch (s) {
        'public' => CollectionVisibility.public,
        _ => CollectionVisibility.private,
      };

  String toWire() => switch (this) {
        CollectionVisibility.public => 'public',
        CollectionVisibility.private => 'private',
      };
}

@Freezed(fromJson: false, toJson: false)
abstract class Collection with _$Collection {
  const factory Collection({
    required String id,
    // Phase 6a — owner_id is required on the wire (`Collection` schema in
    // openapi.yaml). Used to gate owner-only UI such as the visibility toggle
    // without an extra `/v1/users/me` lookup or a membership approximation.
    required String ownerId,
    required String name,
    @Default(0) int entryCount,
    @Default(CollectionVisibility.private) CollectionVisibility visibility,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Collection;

  factory Collection.fromJson(Map<String, dynamic> json) {
    // `owner_id` is `required` in the OpenAPI schema; treat a missing or
    // empty value as a hard parse error rather than silently defaulting to
    // the empty string. A blank id would otherwise compare unequal to every
    // real user id and silently demote the owner to a non-owner view.
    final ownerId = (json['owner_id'] as String?) ?? '';
    if (ownerId.isEmpty) {
      throw const FormatException(
        'Collection.fromJson: missing or empty required field `owner_id`',
      );
    }
    return Collection(
      id: (json['id'] as String?) ?? '',
      ownerId: ownerId,
      name: (json['name'] as String?) ?? '',
      entryCount: (json['entry_count'] as int?) ?? 0,
      visibility:
          CollectionVisibilityParse.fromWire(json['visibility'] as String?),
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
}

/// Owner attribution for a public collection (Phase 6 — `GET /v1/collections/public`).
/// Mirrors the server's slim user shape on the public-collections endpoint.
@Freezed(fromJson: false, toJson: false)
abstract class CollectionOwner with _$CollectionOwner {
  const factory CollectionOwner({
    required String id,
    required String username,
    required String displayUsername,
    String? avatarUrl,
  }) = _CollectionOwner;

  factory CollectionOwner.fromJson(Map<String, dynamic> json) =>
      CollectionOwner(
        id: (json['id'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        displayUsername: (json['display_username'] as String?) ??
            (json['username'] as String? ?? ''),
        avatarUrl: json['avatar_url'] as String?,
      );
}

/// A public collection paired with its owner. Returned by
/// `GET /v1/collections/public`.
@Freezed(fromJson: false, toJson: false)
abstract class CollectionWithOwner with _$CollectionWithOwner {
  const factory CollectionWithOwner({
    required Collection collection,
    required CollectionOwner owner,
  }) = _CollectionWithOwner;

  factory CollectionWithOwner.fromJson(Map<String, dynamic> json) =>
      CollectionWithOwner(
        collection: Collection.fromJson(json),
        owner: CollectionOwner.fromJson(
          (json['owner'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class CollectionEntry with _$CollectionEntry {
  const factory CollectionEntry({
    required BeverageRef beverage,
    String? note,
    @Default('') String addedAt,
  }) = _CollectionEntry;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        beverage: BeverageRef.fromJson(
          (json['beverage'] as Map<String, dynamic>?) ?? const {},
        ),
        note: json['note'] as String?,
        addedAt: (json['added_at'] as String?) ?? '',
      );
}
