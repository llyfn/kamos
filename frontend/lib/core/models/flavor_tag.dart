// KAMOS — FlavorTag (OpenAPI `FlavorTag`).
// Tag taxonomy returned by `/v1/flavor-tags`. Used by the check-in screen and
// to render aggregated profiles.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';

part 'flavor_tag.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class FlavorTag with _$FlavorTag {
  const factory FlavorTag({
    required String id,
    required String slug,
    required String dimension,
    required I18nText name,
  }) = _FlavorTag;

  factory FlavorTag.fromJson(Map<String, dynamic> json) => FlavorTag(
    id: (json['id'] as String?) ?? '',
    slug: (json['slug'] as String?) ?? '',
    dimension: (json['dimension'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
  );
}
