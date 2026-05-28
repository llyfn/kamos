// KAMOS — Widget tests for KamosTabBar (STYLE-008).
//
// Coverage:
//   * Renders exactly 5 tabs in the post-MVP order
//     Feed · Lists · Discover · Notifications · Me.
//   * The _indexFor branch is exercised indirectly: the active tab's icon
//     uses the `ai` token color, inactive tabs use `fg3`. Pumping at each
//     route asserts the mapping `/`→0, `/collections`→1, `/discover`→2,
//     `/notifications`→3, `/me`→4 and any other path falls through to 0.
//   * The unread dot (an AnimatedContainer styled with `koh` + a bgPage
//     border) is present when `unreadCountProvider` resolves > 0 and
//     absent when the provider resolves 0, is still loading, or errored.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/notifications/models/notification.dart';
import 'package:kamos/features/notifications/repository/notification_repository.dart';
import 'package:kamos/l10n/app_localizations.dart';
import 'package:kamos/shared/widgets/kamos_tab_bar.dart';

// ---------------------------------------------------------------------------
// Fakes.

enum _UnreadMode { zero, positive, error, neverComplete }

class _UnreadRepo implements NotificationRepository {
  _UnreadRepo(this.mode);
  final _UnreadMode mode;

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
  Future<int> unreadCount() {
    switch (mode) {
      case _UnreadMode.zero:
        return Future.value(0);
      case _UnreadMode.positive:
        return Future.value(3);
      case _UnreadMode.error:
        return Future.error(StateError('boom'));
      case _UnreadMode.neverComplete:
        // Keeps the provider in AsyncValue.loading for the duration of the
        // test pump — used to exercise the loading branch of the dot
        // visibility check (absent until the future resolves).
        return Completer<int>().future;
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers.

ProviderContainer _containerFor(_UnreadMode mode) {
  final container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(_UnreadRepo(mode)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _wrap(ProviderContainer container, String location) {
  // KamosTabBar uses context.go from go_router — the call site requires a
  // GoRouter ancestor even though tap-driven navigation is not exercised
  // in these tests. Mount a minimal one.
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              bottomNavigationBar: KamosTabBar(location: location),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('KamosTabBar layout', () {
    testWidgets('renders exactly 5 tabs in order Feed · Lists · Discover · '
        'Notifications · Me', (tester) async {
      await tester.pumpWidget(_wrap(_containerFor(_UnreadMode.zero), '/'));
      await tester.pumpAndSettle();

      // Each tab label is rendered as a Text under an InkWell column.
      final labels = ['Feed', 'Lists', 'Discover', 'Notifications', 'Me'];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget,
            reason: '$label tab label missing');
      }

      // Order assertion — fetch every label's vertical position and
      // confirm Feed is leftmost, Me is rightmost.
      final dxs = [
        for (final label in labels)
          tester.getCenter(find.text(label)).dx,
      ];
      for (var i = 1; i < dxs.length; i++) {
        expect(dxs[i], greaterThan(dxs[i - 1]),
            reason: 'tab "${labels[i]}" must sit to the right of '
                '"${labels[i - 1]}"');
      }
    });
  });

  group('KamosTabBar active-tab mapping (_indexFor)', () {
    // Active vs inactive is visible via the icon color: ai (brand) for the
    // active tab, fg3 for the rest. Reading the Icon widget's color is
    // the cheapest proxy for the private _indexFor branch.
    Color iconColorFor(WidgetTester tester, IconData data) {
      return tester
          .widget<Icon>(find.byIcon(data))
          .color!;
    }

    Future<void> pumpAt(WidgetTester tester, String loc) async {
      await tester.pumpWidget(_wrap(_containerFor(_UnreadMode.zero), loc));
      await tester.pumpAndSettle();
    }

    testWidgets('/ activates Feed (index 0)', (tester) async {
      await pumpAt(tester, '/');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.home_outlined), t.ai);
      expect(iconColorFor(tester, Icons.bookmark_outline), t.fg3);
      expect(iconColorFor(tester, Icons.search), t.fg3);
      expect(iconColorFor(tester, Icons.notifications_outlined), t.fg3);
      expect(iconColorFor(tester, Icons.person_outline), t.fg3);
    });

    testWidgets('/collections activates Lists (index 1)', (tester) async {
      await pumpAt(tester, '/collections');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.bookmark_outline), t.ai);
      expect(iconColorFor(tester, Icons.home_outlined), t.fg3);
    });

    testWidgets('/discover activates Discover (index 2)', (tester) async {
      await pumpAt(tester, '/discover');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.search), t.ai);
      expect(iconColorFor(tester, Icons.home_outlined), t.fg3);
    });

    testWidgets('/notifications activates Notifications (index 3)',
        (tester) async {
      await pumpAt(tester, '/notifications');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.notifications_outlined), t.ai);
      expect(iconColorFor(tester, Icons.home_outlined), t.fg3);
    });

    testWidgets('/me activates Me (index 4)', (tester) async {
      await pumpAt(tester, '/me');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.person_outline), t.ai);
      expect(iconColorFor(tester, Icons.home_outlined), t.fg3);
    });

    testWidgets('unknown path falls back to Feed (index 0)', (tester) async {
      await pumpAt(tester, '/check-ins/abc');
      const t = KamosTokens.light;
      expect(iconColorFor(tester, Icons.home_outlined), t.ai);
    });
  });

  group('KamosTabBar unread dot', () {
    // The dot is the only AnimatedContainer inside the tab bar (the
    // surrounding Container is plain). Counting AnimatedContainers under
    // the bar is a stable proxy for dot visibility.
    int dotCount(WidgetTester tester) {
      return find
          .descendant(
            of: find.byType(KamosTabBar),
            matching: find.byType(AnimatedContainer),
          )
          .evaluate()
          .length;
    }

    testWidgets('present when unreadCountProvider resolves > 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_containerFor(_UnreadMode.positive), '/'),
      );
      await tester.pumpAndSettle();
      expect(dotCount(tester), 1);
    });

    testWidgets('absent when unreadCountProvider resolves 0', (tester) async {
      await tester.pumpWidget(_wrap(_containerFor(_UnreadMode.zero), '/'));
      await tester.pumpAndSettle();
      expect(dotCount(tester), 0);
    });

    testWidgets('absent while unreadCountProvider is loading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_containerFor(_UnreadMode.neverComplete), '/'),
      );
      // No pumpAndSettle — the never-completing future would hang. A
      // single pump renders the initial loading state.
      await tester.pump();
      expect(dotCount(tester), 0);
    });

    testWidgets('absent when unreadCountProvider errors '
        '(UnreadCountNotifier swallows the throw and falls back to 0)',
        (tester) async {
      await tester.pumpWidget(_wrap(_containerFor(_UnreadMode.error), '/'));
      await tester.pumpAndSettle();
      expect(dotCount(tester), 0);
    });
  });
}
