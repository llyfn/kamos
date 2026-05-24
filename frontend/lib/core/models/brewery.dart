// KAMOS — Brewery models (OpenAPI `Brewery`, `BreweryRef`).
//
// Optional fields are nullable. Per QA MINOR #2, some servers may emit
// `omitempty` (absent) vs `nullable: true` (present-and-null); we treat both
// as `null` here.
//
// Migration 016: `prefecture` is now a nested `Prefecture` object (which
// itself embeds its `Region`). The previous free-text `prefecture` / `region`
// string fields are gone — the brewery's region is derivable via
// `brewery.prefecture?.region`.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';
import 'prefecture.dart';

part 'brewery.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Brewery with _$Brewery {
  const factory Brewery({
    required String id,
    required I18nText name,
    Prefecture? prefecture,
    int? foundedYear,
    String? website,
    I18nText? description,
    // Populated by `GET /v1/breweries/{id}` and `GET /v1/breweries`. Absent in
    // nested `BreweryRef` embeddings (which use the BreweryRef model) and in
    // /v1/search brewery results — `null` then.
    int? beverageCount,
    @Default('') String createdAt,
  }) = _Brewery;

  factory Brewery.fromJson(Map<String, dynamic> json) => Brewery(
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
    beverageCount: (json['beverage_count'] as num?)?.toInt(),
    createdAt: (json['created_at'] as String?) ?? '',
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class BreweryRef with _$BreweryRef {
  const factory BreweryRef({
    required String id,
    required I18nText name,
    Prefecture? prefecture,
  }) = _BreweryRef;

  factory BreweryRef.fromJson(Map<String, dynamic> json) => BreweryRef(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    prefecture: json['prefecture'] is Map<String, dynamic>
        ? Prefecture.fromJson(json['prefecture'] as Map<String, dynamic>)
        : null,
  );
}
