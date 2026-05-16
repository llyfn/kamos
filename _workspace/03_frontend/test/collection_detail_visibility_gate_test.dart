// KAMOS — Widget test: the visibility toggle on CollectionDetailScreen is
// gated by ownership (Phase 6 fix).
//
// Phase 6 added the public-collections discover tab, which routes to the same
// collection detail screen for any public collection — including ones the
// signed-in user does not own. The toggle must only appear when the viewer
// owns the collection.
//
// Ownership is approximated by membership in `collectionsProvider` (the
// signed-in user's own collections list). This test pins down:
//   * viewer DOES own the collection (id appears in collectionsProvider)
//     → toggle visible
//   * viewer does NOT own the collection (id absent from collectionsProvider)
//     → toggle hidden
//   * collectionsProvider is in the loading state → toggle hidden

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/collection.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/collections/providers/collection_providers.dart';
import 'package:kamos/features/collections/screens/collection_detail_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

Collection _coll(String id) => Collection(id: id, name: 'Cellar', entryCount: 0);

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
      'toggle is visible when the collection id is in the viewer\'s own list',
      (tester) async {
        const id = 'c-own';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsProvider.overrideWith((ref) async =>
                  models.Page<Collection>(items: [_coll(id)])),
              collectionDetailProvider(id).overrideWith((ref) async =>
                  (_coll(id), const models.Page<CollectionEntry>(items: []))),
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
      'toggle is hidden when the collection id is absent from the viewer\'s '
      'own list (non-owner viewing a public collection)',
      (tester) async {
        const id = 'c-someone-elses';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Viewer owns a different collection; the one they're viewing
              // is not theirs.
              collectionsProvider.overrideWith((ref) async =>
                  models.Page<Collection>(items: [_coll('c-mine')])),
              collectionDetailProvider(id).overrideWith((ref) async =>
                  (_coll(id), const models.Page<CollectionEntry>(items: []))),
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
      'toggle is hidden while collectionsProvider is still loading',
      (tester) async {
        const id = 'c-1';
        final completer = Completer<models.Page<Collection>>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Pending — provider stays in the loading state. Resolved in
              // tearDown so no timers leak.
              collectionsProvider.overrideWith((ref) => completer.future),
              collectionDetailProvider(id).overrideWith((ref) async =>
                  (_coll(id), const models.Page<CollectionEntry>(items: []))),
            ],
            child: _wrap(const CollectionDetailScreen(collectionId: id)),
          ),
        );
        // Pump once so the detail provider resolves; collectionsProvider
        // stays pending.
        await tester.pump();

        expect(find.byType(SwitchListTile), findsNothing);

        // Resolve the pending future and settle so the test exits cleanly.
        completer.complete(const models.Page<Collection>(items: []));
        await tester.pumpAndSettle();
      },
    );
  });
}
