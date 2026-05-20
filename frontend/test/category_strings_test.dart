// KAMOS — SPEC §2.1 / brief §6.1 character-exact parity test.
//
// Asserts that the locally-cached category strings exactly match the seeded
// database values. Any drift here is a SPEC blocker — the same strings must
// appear in:
//   - `migrations/002_seed_taxonomy.sql`
//   - `frontend/l10n/intl_{en,ja,ko}.arb`
//   - `frontend/lib/core/i18n/category_labels.dart`

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/i18n/category_labels.dart';

void main() {
  group('SPEC §2.1 category strings', () {
    test('nihonshu × en', () {
      expect(kCategoryStrings['nihonshu_en'], 'Nihonshu (Sake)');
    });
    test('nihonshu × ja', () {
      expect(kCategoryStrings['nihonshu_ja'], '日本酒');
    });
    test('nihonshu × ko', () {
      expect(kCategoryStrings['nihonshu_ko'], '니혼슈 (사케)');
    });

    test('shochu × en', () {
      expect(kCategoryStrings['shochu_en'], 'Shochu');
    });
    test('shochu × ja', () {
      expect(kCategoryStrings['shochu_ja'], '焼酎');
    });
    test('shochu × ko', () {
      expect(kCategoryStrings['shochu_ko'], '쇼츄');
    });

    test('liqueur × en', () {
      expect(kCategoryStrings['liqueur_en'], 'Liqueur');
    });
    test('liqueur × ja', () {
      expect(kCategoryStrings['liqueur_ja'], 'リキュール');
    });
    test('liqueur × ko', () {
      expect(kCategoryStrings['liqueur_ko'], '리큐어');
    });

    test('no abbreviations or substitutions slip in', () {
      // Cross-check: every (slug, locale) covered, nothing else present.
      const expectedKeys = {
        'nihonshu_en', 'nihonshu_ja', 'nihonshu_ko',
        'shochu_en', 'shochu_ja', 'shochu_ko',
        'liqueur_en', 'liqueur_ja', 'liqueur_ko',
      };
      expect(kCategoryStrings.keys.toSet(), equals(expectedKeys));
      for (final v in kCategoryStrings.values) {
        expect(v.isEmpty, isFalse, reason: 'category string must not be empty');
      }
    });
  });
}
