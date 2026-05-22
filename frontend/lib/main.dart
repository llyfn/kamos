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
import 'core/observability/breadcrumb_scrubber.dart';
import 'core/observability/sentry_observer.dart';

// Compile-time configuration. The DSN gate (`kSentryConfigured`) lives in
// `sentry_observer.dart` so other layers can import it without pulling in
// `main.dart`.
const String _sentryDsn = String.fromEnvironment(
  'KAMOS_SENTRY_DSN',
  defaultValue: '',
);
const String _sentryEnv = String.fromEnvironment(
  'KAMOS_ENV',
  defaultValue: 'dev',
);
const String _sentryRelease = String.fromEnvironment(
  'KAMOS_VERSION',
  defaultValue: 'dev',
);

void main() {
  if (_sentryDsn.isEmpty) {
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
        options.dsn = _sentryDsn;
        options.environment = _sentryEnv;
        options.release = _sentryRelease;
        // No client-side performance traces yet — that lands in a later
        // observability slice once the backend OTel pipeline is settled.
        options.tracesSampleRate = 0.0;
        // Privacy: never auto-attach screenshots.
        options.attachScreenshot = false;
        // Redact secrets (Authorization headers, refresh/id tokens, password,
        // secret keys, URL query tokens) from HTTP breadcrumbs so they never
        // leave the device (SPEC §6.9 / SEC-020). The actual walk lives in
        // `breadcrumb_scrubber.dart` so it can be unit-tested without spinning
        // up Sentry.
        options.beforeBreadcrumb = (breadcrumb, hint) {
          if (breadcrumb == null) return null;
          final data = breadcrumb.data;
          if (data == null) return breadcrumb;
          scrubBreadcrumbData(data);
          return breadcrumb;
        };
      },
      appRunner: () => runApp(
        const ProviderScope(
          observers: [SentryProviderObserver()],
          child: KamosApp(),
        ),
      ),
    ),
    (error, stack) {
      Sentry.captureException(error, stackTrace: stack);
    },
  );
}
