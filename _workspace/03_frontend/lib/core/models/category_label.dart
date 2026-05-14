// KAMOS — CategoryLabel (OpenAPI `CategoryLabel`).
//
// `slug` ∈ { nihonshu | shochu | liqueur }. `labelI18n` is the canonical
// SPEC §2.1 strings — see `core/i18n/category_labels.dart` for the local
// authoritative copy and the parity test.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'i18n_text.dart';

part 'category_label.freezed.dart';

@Freezed(fromJson: false, toJson: false)
class CategoryLabel with _$CategoryLabel {
  const factory CategoryLabel({
    required String slug,
    required I18nText labelI18n,
  }) = _CategoryLabel;

  factory CategoryLabel.fromJson(Map<String, dynamic> json) => CategoryLabel(
        slug: (json['slug'] as String?) ?? '',
        labelI18n: I18nText.fromJson(
          (json['label_i18n'] as Map<String, dynamic>?) ?? const {'en': ''},
        ),
      );
}
