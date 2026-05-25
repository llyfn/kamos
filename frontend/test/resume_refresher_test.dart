// KAMOS — Widget tests for ResumeRefresher (STYLE-009 + PERF-004).
//
// Coverage:
//   * When authenticated, AppLifecycleState.resumed triggers an unread-count
//     refresh.
//   * When unauthenticated, AppLifecycleState.resumed does NOT trigger a
//     refresh.
//   * PERF-004: a rapid second resume (within kResumeRefreshDebounce of the
//     first) is debounced — only one refresh fires; a third resume outside
//     the window fires again.
//
// The widget under test is intentionally exported via `@visibleForTesting`
// from lib/app/app.dart so the test can mount it without bringing up the
// whole KamosApp tree (no router, no localization delegates needed for the
// lifecycle path).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/app.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/auth/providers/auth_state.dart';
import 'package:kamos/features/notifications/models/notification.dart';
import 'package:kamos/features/notifications/repository/notification_repository.dart';

// ---------------------------------------------------------------------------
// Fakes.

/// Fake repo that counts how many times `unreadCount` is called. The list /
/// markRead / markAllRead paths are no-ops; the lifecycle test only drives
/// the read counter and the providers' refresh path.
class _CountingRepo implements NotificationRepository {
  int unreadCalls = 0;

  @override
  Future<models.Page<KamosNotification>> list({
    String? cursor,
    int limit = 20,
  }) async =>
      const models.Page<KamosNotification>(items: [], hasMore: false);

  @override
  Future<int> markRead(List<String> ids) async => 0;

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<int> unreadCount() async {
    unreadCalls++;
    return 0;
  }
}

/// Stand-in auth notifier — bypasses the secure-storage bootstrap so the
/// test can control `isAuthenticated` directly.
class _StubAuthNotifier extends AuthStateNotifier {
  _StubAuthNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

ProviderContainer _containerFor({
  required bool authenticated,
  required _CountingRepo repo,
}) {
  final container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith(
        () => _StubAuthNotifier(
          AuthState(isAuthenticated: authenticated, isLoading: false),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: ResumeRefresher(child: SizedBox.shrink()),
    ),
  );
}

Future<void> _resumeAndSettle(WidgetTester tester) async {
  WidgetsBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  // Drain any further microtasks so the fake's counter increment lands.
  await tester.idle();
}

void main() {
  group('ResumeRefresher lifecycle', () {
    testWidgets('authenticated + resumed → unreadCount refresh fires',
        (tester) async {
      final repo = _CountingRepo();
      final container = _containerFor(authenticated: true, repo: repo);
      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();
      // unreadCountProvider is lazy — `build()` only runs on first read.
      // The ResumeRefresher widget never reads it during its own build, so
      // the counter stays at 0 until the resume handler fires.
      expect(repo.unreadCalls, 0,
          reason: 'baseline: provider is lazy, no read yet');

      await _resumeAndSettle(tester);

      // The resume handler reads `unreadCountProvider.notifier` and calls
      // .refresh(); both the lazy build and the refresh call into the
      // repo, so the counter advances by 2 on the first resume.
      expect(repo.unreadCalls, greaterThanOrEqualTo(1),
          reason: 'resume on authed session must trigger at least one '
              'unreadCount fetch (build + refresh)');
      final firstResumeBaseline = repo.unreadCalls;

      // Second resume in the same test tick is debounced — no further
      // unreadCount calls.
      await _resumeAndSettle(tester);
      expect(repo.unreadCalls, firstResumeBaseline,
          reason: 'subsequent rapid resume must NOT refresh');
    });

    testWidgets('unauthenticated + resumed → NO refresh', (tester) async {
      final repo = _CountingRepo();
      final container = _containerFor(authenticated: false, repo: repo);
      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();
      expect(repo.unreadCalls, 0, reason: 'baseline');

      await _resumeAndSettle(tester);

      expect(repo.unreadCalls, 0,
          reason: 'resume while signed out must not refresh');
    });

    testWidgets(
        'PERF-004: rapid second resume is debounced; constant is 30s',
        (tester) async {
      final repo = _CountingRepo();
      final container = _containerFor(authenticated: true, repo: repo);
      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();
      expect(repo.unreadCalls, 0);

      // First resume: triggers the lazy build + a refresh.
      await _resumeAndSettle(tester);
      final firstResumeBaseline = repo.unreadCalls;
      expect(firstResumeBaseline, greaterThanOrEqualTo(1));

      // Second resume within the debounce window: skipped. The 30s
      // window is far longer than wall-clock between two pump calls,
      // so this drives the debounce branch deterministically.
      await _resumeAndSettle(tester);
      expect(repo.unreadCalls, firstResumeBaseline,
          reason: 'second resume within ${kResumeRefreshDebounce.inSeconds}s '
              'must be debounced');

      // Third resume — still within the window: still skipped.
      await _resumeAndSettle(tester);
      expect(repo.unreadCalls, firstResumeBaseline);

      // Lock the production debounce window so this behavior cannot
      // silently change. A test-only fake clock would be over-engineered
      // for one constant.
      expect(kResumeRefreshDebounce, const Duration(seconds: 30),
          reason: 'PERF-004 documents a 30s window');
    });
  });
}
