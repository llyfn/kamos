// KAMOS — Widget tests for NotificationRow + NotificationsScreen.
//
// Coverage (NR-06):
//   * NotificationRow renders the right verb string for each of the five
//     notification types.
//   * NotificationRow renders the localized `notificationsDeletedActor`
//     placeholder when `actor == null`.
//   * The follow_request row exposes inline Approve + Decline buttons; the
//     other four types do not.
//   * NotificationsScreen renders the empty state when the repository
//     returns an empty page.
//   * NotificationsScreen header renders the "Mark all read" button and the
//     button is disabled when no unread rows exist.
//
// Pattern mirrors test/comments_section_error_toast_test.dart: a fake
// repository that `implements NotificationRepository` + a `ProviderContainer`
// with `overrideWithValue`, wrapped in MaterialApp + GoRouter so the row's
// tap target navigation does not crash the bind.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/notifications/models/notification.dart';
import 'package:kamos/features/notifications/providers/notification_providers.dart';
import 'package:kamos/features/notifications/repository/notification_repository.dart';
import 'package:kamos/features/notifications/screens/notifications_screen.dart';
import 'package:kamos/features/notifications/widgets/notification_row.dart';
import 'package:kamos/l10n/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ---------------------------------------------------------------------------
// Fakes.

/// Fake notification repository. `items` seeds the list response; the
/// markRead / markAllRead paths are no-ops returning a sensible count, and
/// unreadCount is derived from the seeded items so the screen's mark-all
/// button-disabled assertion can drive the right state.
class _FakeNotificationRepo implements NotificationRepository {
  _FakeNotificationRepo(this.items);
  final List<KamosNotification> items;

  @override
  Future<models.Page<KamosNotification>> list({
    String? cursor,
    int limit = 20,
  }) async {
    return models.Page<KamosNotification>(items: items, hasMore: false);
  }

  @override
  Future<int> markRead(List<String> ids) async => ids.length;

  @override
  Future<int> markAllRead() async => items.where((n) => n.isUnread).length;

  @override
  Future<int> unreadCount() async =>
      items.where((n) => n.isUnread).length;
}

// ---------------------------------------------------------------------------
// Helpers.

const CheckinUser _actor = CheckinUser(
  id: 'u-1',
  username: 'aiko',
  displayUsername: 'Aiko',
  displayName: 'Aiko T.',
);

KamosNotification _row(NotificationType type, {CheckinUser? actor = _actor}) {
  return KamosNotification(
    id: 'n-${type.wire}',
    type: type,
    actor: actor,
    checkInId: (type == NotificationType.toast ||
            type == NotificationType.comment)
        ? 'ci-1'
        : null,
    createdAt: '2026-05-26T01:00:00Z',
  );
}

GoRouter _noopRouter(Widget home) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
      // Any tap-target the row can navigate to; we don't assert navigation
      // here, the route just needs to resolve cleanly.
      GoRoute(
        path: '/check-ins/:id',
        builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/users/:username',
        builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: _noopRouter(child),
    ),
  );
}

Widget _wrapRow(KamosNotification n, ProviderContainer container) =>
    _wrap(container, NotificationRow(notification: n));

ProviderContainer _emptyContainer() {
  final container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider
          .overrideWithValue(_FakeNotificationRepo(const [])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// NotificationRow tests.

void main() {
  // VisibilityDetector defaults to a 500ms debounce that emits its
  // first notification after the widget tree has been disposed by
  // pumpAndSettle's last frame — that trips the "Timer still pending"
  // invariant. Setting the interval to zero forces synchronous emission
  // so the NotificationsScreen row-mount path can be exercised under
  // test without spawning trailing timers.
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('NotificationRow verb rendering', () {
    testWidgets('toast → "Aiko T. toasted your check-in."', (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.toast), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('toasted your check-in.'), findsOneWidget);
      expect(find.textContaining('Aiko T.'), findsOneWidget);
    });

    testWidgets('comment → "Aiko T. commented on your check-in."',
        (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.comment), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('commented on your check-in.'),
        findsOneWidget,
      );
    });

    testWidgets('follow → "Aiko T. started following you."', (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.follow), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('started following you.'),
        findsOneWidget,
      );
    });

    testWidgets('follow_request → "Aiko T. requested to follow you."',
        (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.followRequest), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('requested to follow you.'),
        findsOneWidget,
      );
    });

    testWidgets('follow_approved → "Aiko T. approved your follow request."',
        (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.followApproved), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('approved your follow request.'),
        findsOneWidget,
      );
    });
  });

  group('NotificationRow soft-deleted actor', () {
    testWidgets('renders the localized Deleted user placeholder',
        (tester) async {
      final n = _row(NotificationType.comment, actor: null);
      await tester.pumpWidget(_wrapRow(n, _emptyContainer()));
      await tester.pumpAndSettle();
      // EN copy from intl_en.arb notificationsDeletedActor.
      expect(find.textContaining('Deleted user'), findsOneWidget);
      expect(
        find.textContaining('commented on your check-in.'),
        findsOneWidget,
      );
    });
  });

  group('NotificationRow inline Approve/Decline buttons', () {
    testWidgets('follow_request row shows Approve + Decline', (tester) async {
      await tester.pumpWidget(
        _wrapRow(_row(NotificationType.followRequest), _emptyContainer()),
      );
      await tester.pumpAndSettle();
      // The follow_request row reuses the inboxApprove / inboxDecline ARB
      // keys for its inline button labels.
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Decline'), findsOneWidget);
    });

    testWidgets('non-request rows have no inline Approve/Decline buttons',
        (tester) async {
      for (final type in [
        NotificationType.toast,
        NotificationType.comment,
        NotificationType.follow,
        NotificationType.followApproved,
      ]) {
        await tester.pumpWidget(
          _wrapRow(_row(type), _emptyContainer()),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Approve'),
          findsNothing,
          reason: '$type must not render an inline Approve button',
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Decline'),
          findsNothing,
          reason: '$type must not render an inline Decline button',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // NotificationsScreen tests.

  group('NotificationsScreen', () {
    testWidgets('renders the empty state when the page is empty',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider
              .overrideWithValue(_FakeNotificationRepo(const [])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container, const NotificationsScreen()));
      await tester.pumpAndSettle();

      // Empty title + body from intl_en.arb.
      expect(find.text('Nothing new'), findsOneWidget);
      expect(
        find.textContaining(
          'Toasts, comments, and follows from other people',
        ),
        findsOneWidget,
      );
      // Empty-state glyph (display kanji).
      expect(find.text('通'), findsOneWidget);
    });

    testWidgets(
        'Mark all read button renders but is disabled when no unread rows',
        (tester) async {
      // Seed with a single READ row so the action button is present (the
      // mark-all action only hides while the provider is loading or in
      // error) but disabled (no unread → onPressed: null).
      final readRow = _row(NotificationType.toast).copyWith(
        readAt: '2026-05-26T02:00:00Z',
      );
      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider
              .overrideWithValue(_FakeNotificationRepo([readRow])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container, const NotificationsScreen()));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Mark all read'),
      );
      expect(button.onPressed, isNull,
          reason: 'no unread rows → mark-all button must be disabled');
    });
  });
}
