// KAMOS — Me.role parsing tests (Phase 5a residual sweep).
//
// `Me.role` mirrors the OpenAPI `UserRole` enum: `user | moderator | admin`.
// The field is `required` in the contract but `Me.fromJson` defaults to
// `UserRole.user` when the key is missing, so older servers stay
// backward-compatible.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/user.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
      'id': 'u-1',
      'username': 'kiku',
      'display_username': 'Kiku',
      'email': 'kiku@example.com',
      'email_verified': true,
      'display_name': 'Kiku',
      'locale': 'en',
      'privacy_mode': 'public',
      'created_at': '2026-05-01T00:00:00Z',
      'stats': {'checkins': 0, 'unique': 0, 'followers': 0, 'following': 0},
    };

void main() {
  group('Me.fromJson role parsing', () {
    test('parses role: "admin" to UserRole.admin', () {
      final me = Me.fromJson({..._baseJson(), 'role': 'admin'});
      expect(me.role, UserRole.admin);
    });

    test('parses role: "moderator" to UserRole.moderator', () {
      final me = Me.fromJson({..._baseJson(), 'role': 'moderator'});
      expect(me.role, UserRole.moderator);
    });

    test('parses role: "user" to UserRole.user', () {
      final me = Me.fromJson({..._baseJson(), 'role': 'user'});
      expect(me.role, UserRole.user);
    });

    test('defaults to UserRole.user when role key is missing', () {
      final me = Me.fromJson(_baseJson());
      expect(me.role, UserRole.user);
    });

    test('defaults to UserRole.user on unknown wire value', () {
      final me = Me.fromJson({..._baseJson(), 'role': 'sysadmin'});
      expect(me.role, UserRole.user);
    });
  });

  group('UserRoleParse.fromWire', () {
    test('maps "admin" -> UserRole.admin', () {
      expect(UserRoleParse.fromWire('admin'), UserRole.admin);
    });
    test('maps "moderator" -> UserRole.moderator', () {
      expect(UserRoleParse.fromWire('moderator'), UserRole.moderator);
    });
    test('maps null -> UserRole.user', () {
      expect(UserRoleParse.fromWire(null), UserRole.user);
    });
  });
}
