// KAMOS — Widget test: PublicCollectionsScreen renders rows, the empty state,
// and the error state with a retry control.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/collection.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/discover/repository/public_collections_repository.dart';
import 'package:kamos/features/discover/screens/public_collections_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

enum _Mode { ok, empty, fail }

class _StubRepo implements PublicCollectionsRepository {
  _StubRepo(this.mode);
  final _Mode mode;
  int calls = 0;

  @override
  Future<models.Page<CollectionWithOwner>> list({String? cursor}) async {
    calls += 1;
    switch (mode) {
      case _Mode.ok:
        return const models.Page<CollectionWithOwner>(
          items: [
            CollectionWithOwner(
              collection: Collection(
                id: 'c1',
                ownerId: 'u1',
                name: 'Late autumn picks',
                entryCount: 5,
                visibility: CollectionVisibility.public,
              ),
              owner: CollectionOwner(
                id: 'u1',
                username: 'mai',
                displayUsername: 'Mai',
              ),
            ),
          ],
          hasMore: false,
        );
      case _Mode.empty:
        return const models.Page<CollectionWithOwner>(items: [], hasMore: false);
      case _Mode.fail:
        throw StateError('boom');
    }
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  group('PublicCollectionsScreen', () {
    testWidgets('renders rows with owner attribution', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicCollectionsRepositoryProvider
                .overrideWithValue(_StubRepo(_Mode.ok)),
          ],
          child: _wrap(const PublicCollectionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Public collections'), findsWidgets);
      expect(find.text('Late autumn picks'), findsOneWidget);
      expect(find.text('by Mai'), findsOneWidget);
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicCollectionsRepositoryProvider
                .overrideWithValue(_StubRepo(_Mode.empty)),
          ],
          child: _wrap(const PublicCollectionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No public collections yet'), findsOneWidget);
    });

    testWidgets('shows error state with retry on failure', (tester) async {
      final repo = _StubRepo(_Mode.fail);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicCollectionsRepositoryProvider.overrideWithValue(repo),
          ],
          child: _wrap(const PublicCollectionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Error view shows the retry affordance (uppercased label from
      // state_views.dart).
      expect(find.text('RETRY'), findsOneWidget);
    });
  });
}
