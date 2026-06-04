// KAMOS — Widget test: CommentsSection's submit-failure paths surface the
// dedicated localized toast for each typed exception, instead of falling
// through to the generic `commentsPostFailed`. Covers:
//
// * Body containing a C0 control char → repository throws
//   `CommentInvalidBodyException` → SnackBar shows `commentsInvalidBody`.
// * Server returns 429 → repository throws `CommentRateLimitedException` →
//   SnackBar shows `commentsRateLimited`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/api/api_exceptions.dart';
import 'package:kamos/core/models/comment.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/comments/repository/comment_repository.dart';
import 'package:kamos/features/comments/widgets/comments_section.dart';
import 'package:kamos/l10n/app_localizations.dart';

class _ThrowingRepo implements CommentRepository {
  _ThrowingRepo(this.toThrow);
  final Object toThrow;

  @override
  Future<models.Page<Comment>> list(String checkInId, {String? cursor}) async {
    return const models.Page<Comment>(items: [], hasMore: false);
  }

  @override
  Future<Comment> create({
    required String checkInId,
    required String body,
  }) async {
    // ignore: only_throw_errors — test stub re-throws caller-supplied exception object verbatim.
    throw toThrow;
  }

  @override
  Future<void> deleteOwn(String commentId) async {}

  @override
  Future<Comment> edit({
    required String commentId,
    required String body,
  }) async {
    // ignore: only_throw_errors — test stub re-throws caller-supplied exception object verbatim.
    throw toThrow;
  }
}

Widget _wrap(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildKamosTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: child),
      ),
    );

Future<void> _submitWith(WidgetTester tester, String body) async {
  await tester.enterText(find.byType(TextField), body);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  group('CommentsSection submit error toasts', () {
    testWidgets(
        'CommentInvalidBodyException from repository surfaces '
        'commentsInvalidBody', (tester) async {
      final repo = _ThrowingRepo(const CommentInvalidBodyException());
      final container = ProviderContainer(overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const CommentsSection(checkInId: 'ci42'),
      ));
      await tester.pumpAndSettle();

      await _submitWith(tester, 'ok body');

      expect(find.text('Comment contains invalid characters'), findsOneWidget);
    });

    testWidgets(
        'CommentRateLimitedException from repository surfaces '
        'commentsRateLimited', (tester) async {
      final repo = _ThrowingRepo(const CommentRateLimitedException());
      final container = ProviderContainer(overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const CommentsSection(checkInId: 'ci42'),
      ));
      await tester.pumpAndSettle();

      await _submitWith(tester, 'ok body');

      expect(
        find.text("You're commenting too fast. Try again in a moment."),
        findsOneWidget,
      );
    });
  });
}
