// KAMOS — Widget test: "Suggest a beverage" tile is reachable when
// `meProvider` is in `AsyncError` (Phase 5a residual sweep).
//
// QA report:
//   docs/history/qa/qa_report_phase5a_flutter.md:72
//   "Suggest-beverage menu unreachable when meProvider errors."
//
// This test pins the fix: even when the profile fetch fails, the suggest
// tile must still mount AND its tap must successfully push the
// `/beverage-requests/new` route.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/user.dart';
import 'package:kamos/features/profile/providers/profile_providers.dart';
import 'package:kamos/features/profile/screens/settings_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/beverage-requests/new',
          // Stub destination — we only need the path to resolve.
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('SUGGEST_PAGE_STUB')),
          ),
        ),
      ],
    );

Widget _wrap(GoRouter router) => MaterialApp.router(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    );

void main() {
  testWidgets(
    'Suggest a beverage tile is visible and tappable when meProvider errors',
    (tester) async {
      final router = _router();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith(
              (_) async => throw Exception('boom — simulated /me failure'),
            ),
          ],
          child: _wrap(router),
        ),
      );
      // Let the FutureProvider settle into AsyncError.
      await tester.pumpAndSettle();

      // The error view for the profile-dependent sections is shown.
      expect(find.text('Could not load. Tap to retry.'), findsOneWidget);

      // The Suggest tile is still mounted (outside the async.when branch).
      final suggest = find.text('Suggest a beverage');
      expect(suggest, findsOneWidget);

      // And tapping it navigates to /beverage-requests/new (stub page).
      await tester.tap(suggest);
      await tester.pumpAndSettle();
      expect(find.text('SUGGEST_PAGE_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'Suggest a beverage tile is also visible in data state',
    (tester) async {
      final router = _router();
      const me = Me(
        user: User(
          id: 'u-1',
          username: 'kiku',
          displayUsername: 'Kiku',
          email: 'kiku@example.com',
          emailVerified: true,
          displayName: 'Kiku',
          locale: 'en',
          privacyMode: 'public',
          createdAt: '2026-05-01T00:00:00Z',
        ),
        stats: UserStats(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith((_) async => me),
          ],
          child: _wrap(router),
        ),
      );
      await tester.pumpAndSettle();

      // Data path renders all sections including suggest. Section headers
      // are uppercased by `_SectionTitle`.
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Suggest a beverage'), findsOneWidget);

      // Delete account is below the fold after the Sign-out tile was added —
      // scroll the ListView to bring it into view before asserting.
      final deleteAccount = find.text('Delete account');
      await tester.scrollUntilVisible(
        deleteAccount,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(deleteAccount, findsOneWidget);
    },
  );
}
