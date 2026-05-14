// KAMOS — SPEC §6.5 i18n fallback test.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/i18n/beverage_name.dart';
import 'package:kamos/core/models/i18n_text.dart';

void main() {
  group('SPEC §6.5 beverage name fallback', () {
    test('ko requested, ko present → ko', () {
      const t = I18nText(en: 'Dassai 23', ja: '獺祭', ko: '닷사이');
      expect(resolveI18n(t, 'ko'), '닷사이');
    });

    test('ko requested, ko missing → en', () {
      const t = I18nText(en: 'Dassai 23', ja: '獺祭');
      expect(resolveI18n(t, 'ko'), 'Dassai 23');
    });

    test('ja requested, ja missing → en', () {
      const t = I18nText(en: 'Iichiko');
      expect(resolveI18n(t, 'ja'), 'Iichiko');
    });

    test('empty ko string falls back to en (treat absent == empty)', () {
      const t = I18nText(en: 'Dassai 23', ja: '獺祭', ko: '');
      expect(resolveI18n(t, 'ko'), 'Dassai 23');
    });

    test('en is always present per OpenAPI; defensive on empty everything', () {
      const t = I18nText(en: '');
      expect(resolveI18n(t, 'ko'), '');
    });
  });
}
