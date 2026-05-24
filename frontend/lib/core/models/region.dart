// KAMOS — Region model (OpenAPI `Region`).
//
// One row of the seed `regions` reference table (Japan's 8 traditional
// regions, e.g. Hokkaido, Tōhoku, Chūbu). Embedded inside `Prefecture` so a
// brewery's `prefecture` field carries enough context to render
// "Niigata (Chūbu)" without a second lookup.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';

part 'region.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Region with _$Region {
  const factory Region({
    required String id,
    required String slug,
    required I18nText name,
    @Default(0) int sortOrder,
  }) = _Region;

  factory Region.fromJson(Map<String, dynamic> json) => Region(
    id: (json['id'] as String?) ?? '',
    slug: (json['slug'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}
