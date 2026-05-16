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
    required String name,
    @Default(0) int entryCount,
    @Default(CollectionVisibility.private) CollectionVisibility visibility,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Collection;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        entryCount: (json['entry_count'] as int?) ?? 0,
        visibility:
            CollectionVisibilityParse.fromWire(json['visibility'] as String?),
        createdAt: (json['created_at'] as String?) ?? '',
        updatedAt: (json['updated_at'] as String?) ?? '',
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
