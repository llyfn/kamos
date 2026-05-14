// KAMOS — Cross-cutting toast bus for the API layer.
//
// The auth interceptor lives outside the widget tree and cannot read
// `AppLocalizations.of(context)`. To keep the i18n source-of-truth in the ARB
// files (not duplicated in Dart strings), the interceptor publishes a
// `ApiToastKind` value on this provider and the app root widget translates it
// to a localized snackbar.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reason for a transport-level toast surfaced by the interceptor. Mapped to
/// localized copy at the widget layer (see `app.dart`).
enum ApiToastKind { unauthorized, network }

/// One-shot signal: the value is replaced each time a new toast should fire,
/// then the listener clears it back to `null` after reading.
class ApiToastBus extends Notifier<ApiToastKind?> {
  @override
  ApiToastKind? build() => null;

  void emit(ApiToastKind kind) {
    state = kind;
  }

  void clear() {
    state = null;
  }
}

final apiToastBusProvider =
    NotifierProvider<ApiToastBus, ApiToastKind?>(ApiToastBus.new);
