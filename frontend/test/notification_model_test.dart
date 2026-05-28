// KAMOS — KamosNotification.fromJson + NotificationType enum tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/features/notifications/models/notification.dart';

void main() {
  group('NotificationType.fromWire', () {
    test('maps every documented wire value', () {
      expect(NotificationType.fromWire('toast'), NotificationType.toast);
      expect(NotificationType.fromWire('comment'), NotificationType.comment);
      expect(NotificationType.fromWire('follow'), NotificationType.follow);
      expect(
        NotificationType.fromWire('follow_request'),
        NotificationType.followRequest,
      );
      expect(
        NotificationType.fromWire('follow_approved'),
        NotificationType.followApproved,
      );
    });

    test('unknown wire value falls back to toast (forward-compat)', () {
      expect(
        NotificationType.fromWire('something_new'),
        NotificationType.toast,
      );
      expect(NotificationType.fromWire(''), NotificationType.toast);
    });

    test('every enum value round-trips through .wire', () {
      for (final v in NotificationType.values) {
        expect(NotificationType.fromWire(v.wire), v);
      }
    });
  });

  group('KamosNotification.fromJson', () {
    test('parses a toast row with an actor and check-in reference', () {
      final n = KamosNotification.fromJson({
        'id': 'n-1',
        'type': 'toast',
        'actor': {
          'id': 'u-1',
          'username': 'aiko',
          'display_username': 'Aiko',
          'display_name': 'Aiko T.',
          'avatar_url': null,
        },
        'check_in_id': 'ci-1',
        'comment_id': null,
        'read_at': null,
        'created_at': '2026-05-26T01:23:45Z',
      });
      expect(n.id, 'n-1');
      expect(n.type, NotificationType.toast);
      expect(n.actor?.username, 'aiko');
      expect(n.checkInId, 'ci-1');
      expect(n.commentId, isNull);
      expect(n.readAt, isNull);
      expect(n.isUnread, isTrue);
      expect(n.createdAt, '2026-05-26T01:23:45Z');
    });

    test('soft-deleted actor arrives as actor: null', () {
      final n = KamosNotification.fromJson({
        'id': 'n-2',
        'type': 'comment',
        'actor': null,
        'check_in_id': 'ci-2',
        'read_at': '2026-05-26T01:30:00Z',
        'created_at': '2026-05-26T01:25:00Z',
      });
      expect(n.actor, isNull);
      expect(n.isUnread, isFalse, reason: 'read_at present → row is read');
    });

    test('missing fields fall back to safe defaults', () {
      final n = KamosNotification.fromJson({});
      expect(n.id, '');
      expect(n.type, NotificationType.toast);
      expect(n.actor, isNull);
      expect(n.checkInId, isNull);
      expect(n.commentId, isNull);
      expect(n.readAt, isNull);
      expect(n.createdAt, '');
      expect(n.isUnread, isTrue);
    });

    test('follow_request type round-trips', () {
      final n = KamosNotification.fromJson({
        'id': 'n-3',
        'type': 'follow_request',
        'actor': {
          'id': 'u-9',
          'username': 'kent',
          'display_username': 'Kent',
          'display_name': 'Kent N.',
        },
        'created_at': '2026-05-26T01:00:00Z',
      });
      expect(n.type, NotificationType.followRequest);
      expect(n.checkInId, isNull);
      expect(n.commentId, isNull);
    });
  });
}
