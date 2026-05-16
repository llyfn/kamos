// KAMOS — Widget test: CommentComposer renders a hint, disables submit on
// empty input, enables on non-empty input, calls the submit callback with
// the trimmed body, and clears the field on a `true` return.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/features/comments/widgets/comment_composer.dart';
import 'package:kamos/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  group('CommentComposer', () {
    testWidgets('submit is disabled until input is non-empty', (tester) async {
      await tester.pumpWidget(_wrap(
        CommentComposer(onSubmit: (_) async => true),
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('tapping post invokes onSubmit with trimmed body and clears',
        (tester) async {
      String? captured;
      await tester.pumpWidget(_wrap(
        CommentComposer(onSubmit: (body) async {
          captured = body;
          return true;
        }),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   Sweet finish.   ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(captured, 'Sweet finish.');
      // Field cleared on success.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('character counter renders current length', (tester) async {
      await tester.pumpWidget(_wrap(
        CommentComposer(onSubmit: (_) async => true),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();

      expect(find.text('3 / 500'), findsOneWidget);
    });
  });
}
