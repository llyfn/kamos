// KAMOS — ARB parity test. Every key declared in `intl_en.arb` must exist in
// `intl_ja.arb` and `intl_ko.arb`. Missing keys are a SPEC §8 blocker.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _l10nDir = 'l10n';

Map<String, dynamic> _readArb(String path) {
  final file = File('$_l10nDir/$path');
  if (!file.existsSync()) {
    throw StateError('Missing ARB file: $_l10nDir/$path');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _userKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  group('ARB parity (en / ja / ko)', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> ja;
    late Map<String, dynamic> ko;

    setUpAll(() {
      en = _readArb('intl_en.arb');
      ja = _readArb('intl_ja.arb');
      ko = _readArb('intl_ko.arb');
    });

    test('ja covers every en key', () {
      final missing = _userKeys(en).difference(_userKeys(ja));
      expect(missing, isEmpty, reason: 'intl_ja.arb missing: $missing');
    });

    test('ko covers every en key', () {
      final missing = _userKeys(en).difference(_userKeys(ko));
      expect(missing, isEmpty, reason: 'intl_ko.arb missing: $missing');
    });

    test('no key has empty value in any locale', () {
      for (final arb in [en, ja, ko]) {
        for (final entry in arb.entries) {
          if (entry.key.startsWith('@')) continue;
          expect(entry.value, isA<String>());
          expect(
            (entry.value as String).isEmpty,
            isFalse,
            reason: '${entry.key} is empty',
          );
        }
      }
    });
  });
}
