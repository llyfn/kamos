// KAMOS — Producer models (OpenAPI `Producer`, `ProducerRef`).
//
// Optional fields are nullable. Per QA MINOR #2, some servers may emit
// `omitempty` (absent) vs `nullable: true` (present-and-null); we treat both
// as `null` here.
//
// Migration 016: `prefecture` is now a nested `Prefecture` object (which
// itself embeds its `Region`). The previous free-text `prefecture` / `region`
// string fields are gone — the producer's region is derivable via
// `producer.prefecture?.region`.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';
import 'prefecture.dart';

part 'producer.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Producer with _$Producer {
  const factory Producer({
    required String id,
    required I18nText name,
    Prefecture? prefecture,
    int? foundedYear,
    String? website,
    I18nText? description,
    // Slice 02 (producer images): optional admin-uploaded image (logo /
    // brewery photo / label collage), resolved server-side from a
    // presigned R2 upload. Absent when the producer has no image.
    @JsonKey(name: 'image_url') String? imageUrl,
    // Populated by `GET /v1/producers/{id}` and `GET /v1/producers`. Absent in
    // nested `ProducerRef` embeddings (which use the ProducerRef model) and in
    // /v1/search producer results — `null` then.
    int? beverageCount,
    @Default('') String createdAt,
  }) = _Producer;

  factory Producer.fromJson(Map<String, dynamic> json) => Producer(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    prefecture: json['prefecture'] is Map<String, dynamic>
        ? Prefecture.fromJson(json['prefecture'] as Map<String, dynamic>)
        : null,
    foundedYear: (json['founded_year'] as num?)?.toInt(),
    website: json['website'] as String?,
    description: json['description'] is Map<String, dynamic>
        ? I18nText.fromJson(json['description'] as Map<String, dynamic>)
        : null,
    imageUrl: json['image_url'] as String?,
    beverageCount: (json['beverage_count'] as num?)?.toInt(),
    createdAt: (json['created_at'] as String?) ?? '',
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class ProducerRef with _$ProducerRef {
  const factory ProducerRef({
    required String id,
    required I18nText name,
    Prefecture? prefecture,
    // Slice 02 (producer images): mirrors Producer.imageUrl on the compact
    // embed so feed / check-in card / collection rows can render the
    // optional 16-dp producer thumbnail without a second fetch.
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _ProducerRef;

  factory ProducerRef.fromJson(Map<String, dynamic> json) => ProducerRef(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    prefecture: json['prefecture'] is Map<String, dynamic>
        ? Prefecture.fromJson(json['prefecture'] as Map<String, dynamic>)
        : null,
    imageUrl: json['image_url'] as String?,
  );
}
