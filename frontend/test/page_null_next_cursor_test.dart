// KAMOS — Page.fromJson tolerates a missing `next_cursor` key.
//
// SPEC §6.6 says the envelope is `{ items, next_cursor, has_more }`. The
// server omits `next_cursor` (rather than emitting `null`) on the
// last page now that `omitempty` lands in Stage 7. This test pins the
// client's tolerance so a future server change that drops the key on the
// last page doesn't blow up the cursor parser.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/page.dart';

void main() {
  group('Page.fromJson', () {
    test('missing next_cursor key parses as nextCursor: null', () {
      final p = Page<String>.fromJson(
        {'items': <Object?>[], 'has_more': false},
        (o) => o as String,
      );
      expect(p.items, isEmpty);
      expect(p.hasMore, false);
      expect(p.nextCursor, isNull);
    });

    test('explicit next_cursor: null also parses', () {
      final p = Page<String>.fromJson(
        {'items': <Object?>[], 'has_more': false, 'next_cursor': null},
        (o) => o as String,
      );
      expect(p.nextCursor, isNull);
    });

    test('non-empty page with cursor parses both fields', () {
      final p = Page<String>.fromJson(
        {
          'items': <Object?>['alpha', 'beta'],
          'has_more': true,
          'next_cursor': 'opaque-token-123',
        },
        (o) => o as String,
      );
      expect(p.items, ['alpha', 'beta']);
      expect(p.hasMore, true);
      expect(p.nextCursor, 'opaque-token-123');
    });

    test('missing has_more defaults to false', () {
      final p = Page<String>.fromJson(
        {'items': <Object?>['x']},
        (o) => o as String,
      );
      expect(p.hasMore, false);
      expect(p.nextCursor, isNull);
    });
  });
}
