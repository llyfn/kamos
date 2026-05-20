// KAMOS — Widget test: CheckInCard renders the Phase 6 comment-count badge
// and tapping it navigates to /check-ins/{id}.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/brewery.dart';
import 'package:kamos/core/models/category_label.dart';
import 'package:kamos/core/models/checkin.dart';
import 'package:kamos/core/models/i18n_text.dart';
import 'package:kamos/features/feed/widgets/check_in_card.dart';
import 'package:kamos/l10n/app_localizations.dart';

FeedItem _feedItem({required int commentCount}) => FeedItem(
      id: 'ci42',
      user: const CheckinUser(
        id: 'u1',
        username: 'mai',
        displayUsername: 'Mai',
        displayName: 'Mai',
      ),
      beverage: BeverageRef(
        id: 'b1',
        name: I18nText.fromJson(const {'en': 'Junmai'}),
        brewery: BreweryRef.fromJson(const {
          'id': 'br1',
          'name': {'en': 'Sample Brewery'},
        }),
        category: CategoryLabel.fromJson(const {
          'slug': 'sake',
        }),
      ),
      commentCount: commentCount,
      toasts: 3,
      createdAt: '2026-05-01T00:00:00Z',
    );

GoRouter _router({required FeedItem item, required ValueChanged<String> onPush}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: CheckInCard(item: item, onToast: () {}),
        ),
      ),
      GoRoute(
        path: '/check-ins/:id',
        builder: (_, state) {
          onPush(state.uri.path);
          return const Scaffold(body: Center(child: Text('DETAIL_STUB')));
        },
      ),
    ],
  );
}

Widget _wrap(GoRouter router) => ProviderScope(
      child: MaterialApp.router(
        theme: buildKamosTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );

void main() {
  group('CheckInCard comment-count badge', () {
    testWidgets('renders the count alongside the toast badge', (tester) async {
      final router = _router(item: _feedItem(commentCount: 7), onPush: (_) {});
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // The badge has the numeric count visible.
      expect(find.text('7'), findsOneWidget);
      // The comment icon is the outlined "mode_comment" icon.
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    });

    testWidgets('tapping the badge navigates to /check-ins/{id}',
        (tester) async {
      String? pushed;
      final router = _router(
        item: _feedItem(commentCount: 2),
        onPush: (path) => pushed = path,
      );
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // Tap the comment icon (the badge wraps it).
      await tester.tap(find.byIcon(Icons.mode_comment_outlined));
      await tester.pumpAndSettle();

      expect(pushed, '/check-ins/ci42');
      expect(find.text('DETAIL_STUB'), findsOneWidget);
    });
  });

  group('FeedItem.fromJson comment_count default', () {
    test('missing comment_count → 0', () {
      final item = FeedItem.fromJson(const {
        'id': 'ci1',
        'user': {'id': 'u', 'username': 'u'},
        'beverage': {'id': 'b'},
      });
      expect(item.commentCount, 0);
    });

    test('parses comment_count when present', () {
      final item = FeedItem.fromJson(const {
        'id': 'ci1',
        'user': {'id': 'u', 'username': 'u'},
        'beverage': {'id': 'b'},
        'comment_count': 12,
      });
      expect(item.commentCount, 12);
    });
  });
}
