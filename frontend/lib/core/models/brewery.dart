// KAMOS — Brewery models (OpenAPI `Brewery`, `BreweryRef`).
//
// Optional fields are nullable. Per QA MINOR #2, some servers may emit
// `omitempty` (absent) vs `nullable: true` (present-and-null); we treat both
// as `null` here.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';

part 'brewery.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Brewery with _$Brewery {
  const factory Brewery({
    required String id,
    required I18nText name,
    String? prefecture,
    String? region,
    int? foundedYear,
    String? website,
    I18nText? description,
    @Default('') String createdAt,
  }) = _Brewery;

  factory Brewery.fromJson(Map<String, dynamic> json) => Brewery(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    prefecture: json['prefecture'] as String?,
    region: json['region'] as String?,
    foundedYear: (json['founded_year'] as num?)?.toInt(),
    website: json['website'] as String?,
    description: json['description'] is Map<String, dynamic>
        ? I18nText.fromJson(json['description'] as Map<String, dynamic>)
        : null,
    createdAt: (json['created_at'] as String?) ?? '',
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class BreweryRef with _$BreweryRef {
  const factory BreweryRef({
    required String id,
    required I18nText name,
    String? region,
  }) = _BreweryRef;

  factory BreweryRef.fromJson(Map<String, dynamic> json) => BreweryRef(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    region: json['region'] as String?,
  );
}
