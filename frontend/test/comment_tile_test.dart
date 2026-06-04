// KAMOS — Widget test: CommentTile shows the overflow (more_horiz) menu only
// for the comment authored by the signed-in user. Tapping the menu opens a
// bottom sheet with Edit / Delete; Delete triggers the confirmation dialog.

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
    testWidgets(
        'renders overflow menu and Delete action when comment is own',
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

      // Single ellipsis affordance on the right edge of the tile.
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      // Inline pencil and trash should NOT live on the tile anymore —
      // only the bottom-sheet exposes them.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Open the sheet.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      // Sheet now exposes the inline icons via ListTile leading widgets.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Tap the Delete row → confirm dialog → tap confirm.
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

    testWidgets('hides overflow menu when comment belongs to another user',
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

      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
