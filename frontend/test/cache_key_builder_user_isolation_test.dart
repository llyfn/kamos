// KAMOS — Phase 7 follow-up. Verifies that the HTTP cache key namespace is
// bound to the currently-authenticated user's JWT `sub` claim, closing the
// offline cross-user leak described in qa_report_phase7_flutter.md MAJOR #2.
//
// Two assertions:
//   1. Different access tokens (different `sub`) produce different cache keys
//      for the same URL.
//   2. A null token (anonymous) produces a different cache key from any
//      authenticated token for the same URL.
//
// Implementation note: this test exercises `cacheKeyBuilder` directly rather
// than through Dio so it stays fast and deterministic. The integration with
// the cache interceptor (and `dioProvider.invalidate` on logout) is covered
// by `auth_logout_cache_invalidation_test.dart`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/api_client.dart';
import 'package:kamos/core/storage/secure_storage.dart';

/// Build an unsigned JWT-shaped string with the given `sub` claim. The
/// signature segment is left as `sig` — the client decoder doesn't verify.
String _jwtFor(String sub) {
  String b64(String s) => base64Url
      .encode(utf8.encode(s))
      .replaceAll('=', ''); // RFC 7515 §2: no padding.
  final header = b64('{"alg":"HS256","typ":"JWT"}');
  final payload = b64('{"sub":"$sub","exp":9999999999}');
  return '$header.$payload.sig';
}

void main() {
  group('cacheKeyBuilder user isolation', () {
    tearDown(() {
      // Make sure subsequent tests start from a clean snapshot.
      SecureStorageService.setAccessTokenSnapshotForTest(null);
    });

    test('two different tokens produce different keys for the same URL', () {
      final url = Uri.parse('https://example.test/v1/users/me');

      SecureStorageService.setAccessTokenSnapshotForTest(_jwtFor('user-A'));
      final keyA = cacheKeyBuilder(url: url);

      SecureStorageService.setAccessTokenSnapshotForTest(_jwtFor('user-B'));
      final keyB = cacheKeyBuilder(url: url);

      expect(
        keyA,
        isNot(equals(keyB)),
        reason: 'cache keys must be per-user so User B cannot read '
            "User A's cached response under any condition",
      );
    });

    test('an authenticated token and null produce different keys', () {
      final url = Uri.parse('https://example.test/v1/feed');

      SecureStorageService.setAccessTokenSnapshotForTest(_jwtFor('user-A'));
      final keyAuthed = cacheKeyBuilder(url: url);

      SecureStorageService.setAccessTokenSnapshotForTest(null);
      final keyAnon = cacheKeyBuilder(url: url);

      expect(keyAuthed, isNot(equals(keyAnon)));
    });

    test('the same token produces a stable key (cache hits still work)', () {
      final url = Uri.parse('https://example.test/v1/categories');
      SecureStorageService.setAccessTokenSnapshotForTest(_jwtFor('user-A'));

      final first = cacheKeyBuilder(url: url);
      final second = cacheKeyBuilder(url: url);

      expect(first, equals(second));
    });

    test('malformed token falls back to the anon namespace', () {
      final url = Uri.parse('https://example.test/v1/categories');

      SecureStorageService.setAccessTokenSnapshotForTest('not-a-jwt');
      final keyMalformed = cacheKeyBuilder(url: url);

      SecureStorageService.setAccessTokenSnapshotForTest(null);
      final keyAnon = cacheKeyBuilder(url: url);

      expect(keyMalformed, equals(keyAnon));
    });
  });
}
