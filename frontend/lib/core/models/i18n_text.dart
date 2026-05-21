// KAMOS — I18nText model (OpenAPI `I18nText`).
//
// The `ko` field is optional per the contract. The backend emits `omitempty`
// for empty Korean strings (QA MINOR #3), so absent and empty are treated
// identically — both fall back to `en` via `resolveI18n`.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'i18n_text.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class I18nText with _$I18nText {
  const factory I18nText({required String en, String? ja, String? ko}) =
      _I18nText;

  factory I18nText.fromJson(Map<String, dynamic> json) => I18nText(
    en: (json['en'] as String?) ?? '',
    ja: json['ja'] as String?,
    ko: json['ko'] as String?,
  );
}
