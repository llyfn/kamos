// KAMOS — Prefecture model (OpenAPI `Prefecture`).
//
// One row of the seed `prefectures` reference table. `region` is embedded so
// a brewery's `prefecture` field carries enough context to render
// "Niigata (Chūbu)" without a second lookup.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';
import 'region.dart';

part 'prefecture.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Prefecture with _$Prefecture {
  const factory Prefecture({
    required String id,
    required String slug,
    required I18nText name,
    @Default(0) int sortOrder,
    required Region region,
  }) = _Prefecture;

  factory Prefecture.fromJson(Map<String, dynamic> json) => Prefecture(
    id: (json['id'] as String?) ?? '',
    slug: (json['slug'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    region: Region.fromJson(
      (json['region'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}
