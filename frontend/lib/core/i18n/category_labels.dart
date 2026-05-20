// KAMOS — Category labels (SPEC §2.1 / brief §6.1).
//
// Hardcoded character-for-character to match
// `migrations/002_seed_taxonomy.sql`. The API also
// returns `label_i18n` from `/v1/categories`, but the client must NEVER show a
// different string for these three slugs — this map is the local fallback /
// canonical reference, and `category_strings_test.dart` asserts it.

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

enum CategorySlug { nihonshu, shochu, liqueur }

CategorySlug? categorySlugFromString(String? raw) {
  switch (raw) {
    case 'nihonshu':
      return CategorySlug.nihonshu;
    case 'shochu':
      return CategorySlug.shochu;
    case 'liqueur':
      return CategorySlug.liqueur;
    default:
      return null;
  }
}

String categorySlugToWire(CategorySlug slug) {
  switch (slug) {
    case CategorySlug.nihonshu:
      return 'nihonshu';
    case CategorySlug.shochu:
      return 'shochu';
    case CategorySlug.liqueur:
      return 'liqueur';
  }
}

/// SPEC §2.1 canonical strings, character-exact across (slug, locale).
///
/// Keys are `${slug}_${locale}` — e.g. `nihonshu_en`. The intent is for a
/// dedicated test to enumerate every pair and assert equality, so any drift
/// surfaces in CI rather than in QA.
const Map<String, String> kCategoryStrings = {
  'nihonshu_en': 'Nihonshu (Sake)',
  'nihonshu_ja': '日本酒',
  'nihonshu_ko': '니혼슈 (사케)',
  'shochu_en':   'Shochu',
  'shochu_ja':   '焼酎',
  'shochu_ko':   '쇼츄',
  'liqueur_en':  'Liqueur',
  'liqueur_ja':  'リキュール',
  'liqueur_ko':  '리큐어',
};

/// Resolve a SPEC category string from a [BuildContext]. Goes through ARB so
/// app-wide locale + fallback rules apply automatically.
String categoryLabel(BuildContext context, CategorySlug slug) {
  final l = AppLocalizations.of(context);
  switch (slug) {
    case CategorySlug.nihonshu:
      return l.categoryNihonshu;
    case CategorySlug.shochu:
      return l.categoryShochu;
    case CategorySlug.liqueur:
      return l.categoryLiqueur;
  }
}
