// KAMOS — Sentry breadcrumb scrubber tests (SEC-020).
//
// Verifies that the breadcrumb redactor strips every secret-bearing field we
// know about from a synthetic breadcrumb.data payload before it leaves the
// device: Authorization headers (legacy SEC-019 contract), refresh / id
// tokens, password fields, and URL query strings carrying `token=` or
// `refresh_token=`.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/observability/breadcrumb_scrubber.dart';

void main() {
  group('scrubBreadcrumbData', () {
    test('redacts Authorization header at the root (legacy contract)', () {
      final data = <String, dynamic>{
        'headers': <String, dynamic>{
          'Authorization': 'Bearer eyJ.actual.jwt',
          'Content-Type': 'application/json',
        },
      };
      scrubBreadcrumbData(data);
      final headers = data['headers'] as Map;
      expect(headers['Authorization'], '[redacted]');
      // Non-secret keys untouched.
      expect(headers['Content-Type'], 'application/json');
    });

    test('redacts Authorization on request.headers (case-insensitive)', () {
      final data = <String, dynamic>{
        'request': <String, dynamic>{
          'headers': <String, dynamic>{
            'authorization': 'Bearer eyJ.actual.jwt',
          },
        },
      };
      scrubBreadcrumbData(data);
      final headers = (data['request'] as Map)['headers'] as Map;
      expect(headers['authorization'], '[redacted]');
    });

    test('redacts Authorization on response.headers', () {
      final data = <String, dynamic>{
        'response': <String, dynamic>{
          'headers': <String, dynamic>{
            'Authorization': 'Bearer leaked-on-error',
          },
        },
      };
      scrubBreadcrumbData(data);
      final headers = (data['response'] as Map)['headers'] as Map;
      expect(headers['Authorization'], '[redacted]');
    });

    test('redacts Authorization on top-level response_headers', () {
      final data = <String, dynamic>{
        'response_headers': <String, dynamic>{
          'Authorization': 'Bearer leaked',
        },
      };
      scrubBreadcrumbData(data);
      expect(
        (data['response_headers'] as Map)['Authorization'],
        '[redacted]',
      );
    });

    test('redacts refresh_token and id_token in extra context', () {
      final data = <String, dynamic>{
        'extra': <String, dynamic>{
          'refresh_token': 'rt.value.here',
          'id_token': 'idt.value.here',
          'safe_field': 'visible',
        },
      };
      scrubBreadcrumbData(data);
      final extra = data['extra'] as Map;
      expect(extra['refresh_token'], '[redacted]');
      expect(extra['id_token'], '[redacted]');
      expect(extra['safe_field'], 'visible');
    });

    test('redacts nested password / secret keys in contexts', () {
      final data = <String, dynamic>{
        'contexts': <String, dynamic>{
          'auth': <String, dynamic>{
            'password': 'hunter2',
            'api_secret': 'sk_live_xxx',
            'user_id': 'usr_123',
          },
        },
      };
      scrubBreadcrumbData(data);
      final auth = (data['contexts'] as Map)['auth'] as Map;
      expect(auth['password'], '[redacted]');
      expect(auth['api_secret'], '[redacted]');
      expect(auth['user_id'], 'usr_123');
    });

    test('strips token query param from a URL string field', () {
      final data = <String, dynamic>{
        'url': 'https://api.example.com/v1/me?token=abc&keep=1',
      };
      scrubBreadcrumbData(data);
      final scrubbed = data['url'] as String;
      // The literal secret is gone.
      expect(scrubbed.contains('abc'), isFalse);
      // Non-secret params are preserved.
      expect(scrubbed.contains('keep=1'), isTrue);
      // The marker survives in either raw or URL-encoded form (Uri.replace
      // percent-encodes the brackets).
      expect(
        scrubbed.contains('[redacted]') ||
            scrubbed.contains('%5Bredacted%5D'),
        isTrue,
        reason: 'expected redaction marker (raw or %-encoded) in $scrubbed',
      );
    });

    test('strips refresh_token query param even when nested deep', () {
      final data = <String, dynamic>{
        'request': <String, dynamic>{
          'url': 'https://api.example.com/v1/auth/refresh'
              '?refresh_token=rt.secret&device=ios',
        },
      };
      scrubBreadcrumbData(data);
      final url = (data['request'] as Map)['url'] as String;
      expect(url.contains('rt.secret'), isFalse);
      expect(url.contains('device=ios'), isTrue);
    });

    test('redacts every secret in a single multi-shape breadcrumb', () {
      // The acceptance-criterion test from the task description: one
      // breadcrumb with Authorization, refresh_token, id_token, and a URL
      // with ?token=abc; none of those secrets may survive.
      final data = <String, dynamic>{
        'url': 'https://api.example.com/oauth?token=abc',
        'headers': <String, dynamic>{
          'Authorization': 'Bearer jwt.value',
        },
        'extra': <String, dynamic>{
          'refresh_token': 'rt.value',
          'id_token': 'idt.value',
        },
      };
      scrubBreadcrumbData(data);

      // Helper: stringify the whole map and assert none of the originals leak.
      final serialised = data.toString();
      expect(serialised.contains('jwt.value'), isFalse,
          reason: 'Authorization JWT must not survive scrub');
      expect(serialised.contains('rt.value'), isFalse,
          reason: 'refresh_token must not survive scrub');
      expect(serialised.contains('idt.value'), isFalse,
          reason: 'id_token must not survive scrub');
      expect(serialised.contains('?token=abc'), isFalse,
          reason: 'URL query token must not survive scrub');
      expect(serialised.contains('token=abc'), isFalse,
          reason: 'URL query token must not survive scrub (no leading ?)');
    });

    test('handles headers_raw legacy string blob', () {
      final data = <String, dynamic>{
        'headers_raw': 'Host: example.com\r\nAuthorization: Bearer xxx',
      };
      scrubBreadcrumbData(data);
      expect(data['headers_raw'], '[redacted]');
    });

    test('does not crash on null / empty / non-secret payloads', () {
      final empty = <String, dynamic>{};
      scrubBreadcrumbData(empty);
      expect(empty, isEmpty);

      final benign = <String, dynamic>{
        'message': 'tapped feed item',
        'count': 42,
        'tags': ['hot', 'new'],
      };
      scrubBreadcrumbData(benign);
      expect(benign['message'], 'tapped feed item');
      expect(benign['count'], 42);
      expect(benign['tags'], ['hot', 'new']);
    });

    test('bounded recursion: deeply nested payload does not stack-overflow',
        () {
      // Build a chain deeper than the internal cap. The scrubber must just
      // stop walking, not throw.
      Map<String, dynamic> node = <String, dynamic>{'leaf_token': 'should_stay'};
      for (var i = 0; i < 20; i++) {
        node = <String, dynamic>{'child': node};
      }
      // Wrap so it lives under `extra` (an entry point the scrubber walks).
      final data = <String, dynamic>{'extra': node};
      // Should not throw.
      scrubBreadcrumbData(data);
      // The leaf is deeper than the depth cap, so by contract we accept that
      // it MAY survive. The test asserts no exception was thrown, not that
      // pathological depths are scrubbed.
    });

    test('redacts secret-looking keys in list elements', () {
      final data = <String, dynamic>{
        'extra': <String, dynamic>{
          'events': <dynamic>[
            <String, dynamic>{'authorization': 'Bearer leak', 'name': 'login'},
            <String, dynamic>{'name': 'logout'},
          ],
        },
      };
      scrubBreadcrumbData(data);
      final events = ((data['extra'] as Map)['events'] as List);
      expect((events[0] as Map)['authorization'], '[redacted]');
      expect((events[0] as Map)['name'], 'login');
      expect((events[1] as Map)['name'], 'logout');
    });
  });
}
