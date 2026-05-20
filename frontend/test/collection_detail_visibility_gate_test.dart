// KAMOS — Widget test: the visibility toggle on CollectionDetailScreen is
// gated by ownership (Phase 6a — direct `owner_id` compare).
//
// Phase 6 added the public-collections discover tab, which routes to the same
// collection detail screen for any public collection — including ones the
// signed-in user does not own. The toggle must only appear when the viewer
// owns the collection.
//
// Phase 6a replaced the membership-in-collectionsProvider approximation with
// a direct compare: `me.user.id == collection.ownerId`. This test pins down:
//   * viewer's id matches collection.ownerId → toggle visible
//   * viewer's id does NOT match collection.ownerId (e.g., reached via the
//     public-collections discover tab) → toggle hidden
//   * meProvider is in the loading state → toggle hidden

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/collection.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/core/models/user.dart';
import 'package:kamos/features/collections/providers/collection_providers.dart';
import 'package:kamos/features/collections/screens/collection_detail_screen.dart';
import 'package:kamos/features/profile/providers/profile_providers.dart';
import 'package:kamos/l10n/app_localizations.dart';

Collection _coll(String id, {required String ownerId}) =>
    Collection(id: id, ownerId: ownerId, name: 'Cellar', entryCount: 0);

Me _me(String userId) => Me(
      user: User(id: userId, username: 'mai', displayUsername: 'Mai'),
      stats: const UserStats(),
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  group('CollectionDetailScreen visibility toggle gating', () {
    testWidgets(
      'toggle is visible when me.user.id matches collection.ownerId',
      (tester) async {
        const id = 'c-own';
        const uid = 'u-mai';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              meProvider.overrideWith((ref) async => _me(uid)),
              collectionDetailProvider(id).overrideWith((ref) async => (
                _coll(id, ownerId: uid),
                const models.Page<CollectionEntry>(items: []),
              )),
            ],
            child: _wrap(const CollectionDetailScreen(collectionId: id)),
          ),
        );
        await tester.pumpAndSettle();

        // SwitchListTile is the visibility toggle.
        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.text('Public collection'), findsOneWidget);
      },
    );

    testWidgets(
      'toggle is hidden when me.user.id does not match collection.ownerId '
      '(non-owner viewing a public collection)',
      (tester) async {
        const id = 'c-someone-elses';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Viewer is u-mai; the collection belongs to u-other.
              meProvider.overrideWith((ref) async => _me('u-mai')),
              collectionDetailProvider(id).overrideWith((ref) async => (
                _coll(id, ownerId: 'u-other'),
                const models.Page<CollectionEntry>(items: []),
              )),
            ],
            child: _wrap(const CollectionDetailScreen(collectionId: id)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.text('Public collection'), findsNothing);
      },
    );

    testWidgets(
      'toggle is hidden while meProvider is still loading',
      (tester) async {
        const id = 'c-1';
        const uid = 'u-mai';
        final completer = Completer<Me>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Pending — meProvider stays in the loading state. Resolved in
              // tearDown so no timers leak.
              meProvider.overrideWith((ref) => completer.future),
              collectionDetailProvider(id).overrideWith((ref) async => (
                _coll(id, ownerId: uid),
                const models.Page<CollectionEntry>(items: []),
              )),
            ],
            child: _wrap(const CollectionDetailScreen(collectionId: id)),
          ),
        );
        // Pump once so the detail provider resolves; meProvider stays pending.
        await tester.pump();

        expect(find.byType(SwitchListTile), findsNothing);

        // Resolve the pending future and settle so the test exits cleanly.
        completer.complete(_me(uid));
        await tester.pumpAndSettle();
      },
    );
  });
}
