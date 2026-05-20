// KAMOS — Widget test: CommentTile shows the delete affordance only for the
// comment authored by the signed-in user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/comment.dart';
import 'package:kamos/core/models/user.dart';
import 'package:kamos/features/comments/widgets/comment_tile.dart';
import 'package:kamos/features/profile/providers/profile_providers.dart';
import 'package:kamos/l10n/app_localizations.dart';

Me _me(String id) => Me(
      user: User(
        id: id,
        username: id,
        displayUsername: id,
        displayName: id,
      ),
      stats: const UserStats(),
    );

Comment _comment({required String userId, String id = 'cm1'}) => Comment(
      id: id,
      checkInId: 'ci1',
      user: CheckinUser(
        id: userId,
        username: userId,
        displayUsername: userId,
        displayName: userId,
      ),
      body: 'A tasting note.',
      createdAt: '2026-05-01T12:00:00Z',
    );

Widget _wrapMaterial(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  group('CommentTile', () {
    testWidgets('renders delete icon when comment is signed-in user\'s own',
        (tester) async {
      var deletedWith = '';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith((_) async => _me('u-self')),
          ],
          child: _wrapMaterial(CommentTile(
            comment: _comment(userId: 'u-self'),
            onDelete: (id) async => deletedWith = id,
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Tap delete → confirm dialog appears → tap confirm.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete this comment?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(deletedWith, 'cm1');
    });

    testWidgets('hides delete icon when comment belongs to another user',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith((_) async => _me('u-self')),
          ],
          child: _wrapMaterial(CommentTile(
            comment: _comment(userId: 'u-other'),
            onDelete: (_) async {},
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
