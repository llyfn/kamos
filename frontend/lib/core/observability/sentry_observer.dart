// KAMOS — Riverpod -> Sentry bridge.
//
// Forwards provider build failures to Sentry when (and only when) the SDK is
// configured. When `KAMOS_SENTRY_DSN` is empty `kSentryConfigured` is false and
// this observer is never registered, so this file never touches Sentry at all
// in dev / test runs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// True when `KAMOS_SENTRY_DSN` was supplied at compile time via
/// `--dart-define`. Read once at startup; the rest of the app uses this to
/// decide whether to wire Sentry-aware code paths.
///
/// Note: `String.isNotEmpty` is not const-evaluable, so this is written as a
/// const equality comparison instead.
const bool kSentryConfigured = String.fromEnvironment('KAMOS_SENTRY_DSN') != '';

/// Captures every provider build failure as a Sentry exception so we can see
/// repository / decoder bugs in production without the user having to crash
/// the whole app.
final class SentryProviderObserver extends ProviderObserver {
  const SentryProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final provider = context.provider;
    final name = provider.name ?? provider.runtimeType.toString();
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({'provider': name}),
    );
  }
}
