// KAMOS — i18n fallback helpers for catalog text (SPEC §6.5).
//
// `ko` missing → use `en`. `ja` missing → use `en`. Never emit empty strings
// or wrong-locale glyphs. This is applied client-side per HANDOFF.md.

import '../models/i18n_text.dart';

/// Resolve an [I18nText] in the user's [locale].
///
/// Order:
/// 1. The requested locale, if present and non-empty.
/// 2. The `en` value (always required by the OpenAPI contract).
/// 3. The next non-empty value (defensive — should never trigger).
String resolveI18n(I18nText text, String locale) {
  String? candidate;
  switch (locale) {
    case 'ja':
      candidate = text.ja;
      break;
    case 'ko':
      candidate = text.ko;
      break;
    case 'en':
    default:
      candidate = text.en;
  }
  if (candidate != null && candidate.isNotEmpty) return candidate;

  if (text.en.isNotEmpty) return text.en;
  if ((text.ja ?? '').isNotEmpty) return text.ja!;
  if ((text.ko ?? '').isNotEmpty) return text.ko!;
  return '';
}
