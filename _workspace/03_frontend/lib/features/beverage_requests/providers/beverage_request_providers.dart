// KAMOS — Beverage-request submission state (Phase 5 user-side).
//
// `submitBeverageRequestProvider` owns the idle/loading/data/error machine
// for a single submit attempt. The screen calls `notifier.submit(req)` and
// watches the resulting `AsyncValue<void>`:
//
//   * `AsyncData(null)`  → success, screen shows toast and pops
//   * `AsyncError(e, _)` → failure, screen shows inline error
//   * `AsyncLoading()`   → submit button shows spinner, gated against re-tap

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/beverage_request.dart';
import '../repository/beverage_request_repository.dart';

class SubmitBeverageRequestNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial idle state — no work done at build time.
    return;
  }

  Future<void> submit(BeverageRequest req) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(beverageRequestRepositoryProvider).submit(req),
    );
  }

  /// Reset to idle (used when the screen is disposed mid-error so a re-entry
  /// starts clean).
  void reset() {
    state = const AsyncValue.data(null);
  }
}

final submitBeverageRequestProvider =
    AsyncNotifierProvider.autoDispose<SubmitBeverageRequestNotifier, void>(
  SubmitBeverageRequestNotifier.new,
);
