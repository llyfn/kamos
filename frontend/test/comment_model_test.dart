// KAMOS — Comment.fromJson tests (Phase 6).

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses full wire shape', () {
      final c = Comment.fromJson(const {
        'id': 'cm1',
        'check_in_id': 'ci42',
        'user': {
          'id': 'u9',
          'username': 'mai',
          'display_username': 'Mai',
          'display_name': 'Mai S.',
          'avatar_url': 'https://example.test/a.png',
        },
        'body': 'Tastes like pear.',
        'created_at': '2026-05-01T12:00:00Z',
      });
      expect(c.id, 'cm1');
      expect(c.checkInId, 'ci42');
      expect(c.user?.username, 'mai');
      expect(c.user?.displayUsername, 'Mai');
      expect(c.body, 'Tastes like pear.');
      expect(c.createdAt, '2026-05-01T12:00:00Z');
      expect(c.deletedAt, isNull);
    });

    test('missing fields fall back to safe defaults', () {
      final c = Comment.fromJson(const {});
      expect(c.id, '');
      expect(c.checkInId, '');
      expect(c.user, isNull);
      expect(c.body, '');
      expect(c.createdAt, '');
    });

    test('null user (author hard-purged) parses to null', () {
      // Stage 7 (M-12.2) — migration 013 sets comments.user_id ON DELETE
      // SET NULL. The wire shape carries `"user": null` for orphaned
      // rows; Comment.fromJson must accept that.
      final c = Comment.fromJson(const {
        'id': 'cm1',
        'check_in_id': 'ci42',
        'user': null,
        'body': 'orphaned',
        'created_at': '2026-05-01T12:00:00Z',
      });
      expect(c.user, isNull);
      expect(c.body, 'orphaned');
    });

    test('preserves deleted_at when present', () {
      final c = Comment.fromJson(const {
        'id': 'cm1',
        'body': 'x',
        'deleted_at': '2026-05-02T00:00:00Z',
      });
      expect(c.deletedAt, '2026-05-02T00:00:00Z');
    });
  });
}
