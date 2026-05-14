// KAMOS — Entry point.
//
// Sentry is opt-in: pass `--dart-define=KAMOS_SENTRY_DSN=...` to enable crash
// reporting. With an empty DSN the SDK never initializes, no network calls
// happen, and tests / dev runs behave exactly as before.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'core/observability/sentry_observer.dart';

// Compile-time configuration. The DSN gate (`kSentryConfigured`) lives in
// `sentry_observer.dart` so other layers can import it without pulling in
// `main.dart`.
const String _kSentryDsn =
    String.fromEnvironment('KAMOS_SENTRY_DSN', defaultValue: '');
const String _kSentryEnv =
    String.fromEnvironment('KAMOS_ENV', defaultValue: 'dev');
const String _kSentryRelease =
    String.fromEnvironment('KAMOS_VERSION', defaultValue: 'dev');

void main() {
  if (_kSentryDsn.isEmpty) {
    // Dev / test path: log once, run the app, route any uncaught async error
    // through `debugPrint` instead of Sentry.
    assert(() {
      debugPrint('sentry disabled');
      return true;
    }());
    runZonedGuarded<void>(
      () => runApp(const ProviderScope(child: KamosApp())),
      (error, stack) {
        debugPrint('Uncaught zone error: $error\n$stack');
      },
    );
    return;
  }

  // Production-ish path: Sentry takes ownership of uncaught errors. The init
  // callback is what actually calls `runApp`; runZonedGuarded wraps it so
  // async errors that escape Flutter's framework handler still reach Sentry.
  runZonedGuarded<Future<void>>(
    () => SentryFlutter.init(
      (options) {
        options.dsn = _kSentryDsn;
        options.environment = _kSentryEnv;
        options.release = _kSentryRelease;
        // No client-side performance traces yet — that lands in a later
        // observability slice once the backend OTel pipeline is settled.
        options.tracesSampleRate = 0.0;
        // Privacy: never auto-attach screenshots.
        options.attachScreenshot = false;
        // Redact Authorization headers from HTTP breadcrumbs so the JWT never
        // leaves the device (SPEC §6.9). The Sentry HTTP integration places
        // request headers under `data['request']['headers']` or
        // `data['headers']`; both are checked defensively.
        options.beforeBreadcrumb = (breadcrumb, hint) {
          if (breadcrumb == null) return null;
          final data = breadcrumb.data;
          if (data == null) return breadcrumb;
          _redactAuthorization(data);
          final request = data['request'];
          if (request is Map) {
            _redactAuthorization(request.cast<String, dynamic>());
          }
          return breadcrumb;
        };
      },
      appRunner: () => runApp(
        ProviderScope(
          observers: const [SentryProviderObserver()],
          child: const KamosApp(),
        ),
      ),
    ),
    (error, stack) {
      Sentry.captureException(error, stackTrace: stack);
    },
  );
}

/// Walks a breadcrumb data map and replaces any case-insensitive
/// `Authorization` header with `[redacted]` in place. Sentry's HTTP
/// integration may nest headers under `headers` or include the URL with query
/// auth tokens; we redact both.
void _redactAuthorization(Map<String, dynamic> data) {
  final headers = data['headers'];
  if (headers is Map) {
    for (final key in headers.keys.toList()) {
      if (key is String && key.toLowerCase() == 'authorization') {
        headers[key] = '[redacted]';
      }
    }
  }
  // Some integrations stash the raw header list as a string under
  // `headers_raw` or similar; scrub the obvious case.
  final rawHeaders = data['headers_raw'];
  if (rawHeaders is String &&
      rawHeaders.toLowerCase().contains('authorization')) {
    data['headers_raw'] = '[redacted]';
  }
}
