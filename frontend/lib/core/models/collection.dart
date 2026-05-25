// KAMOS — Collection models (OpenAPI `Collection`, `CollectionEntry`).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';

part 'collection.freezed.dart';

/// Collection visibility. `private` is the default for backward
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
    // owner_id is required on the wire (`Collection` schema in
    // openapi.yaml). Used to gate owner-only UI such as the visibility
    // toggle without an extra `/v1/users/me` lookup or a membership
    // approximation.
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
      visibility: CollectionVisibilityParse.fromWire(
        json['visibility'] as String?,
      ),
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
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
