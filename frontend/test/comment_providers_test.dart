// KAMOS — CommentsNotifier behavior tests (Phase 6 fix).
//
// Pins down the DESC-ordering / prepend-on-post contract:
//
// * `build()` resolves to a CommentsState that reflects the repository's
//   Page<Comment>.
// * Optimistic `post()` prepends the new comment to the HEAD of the list
//   (newest at top) — this is the contract the server's DESC ordering
//   implies.
// * `loadMore()` appends older comments to the TAIL using the keyset cursor.
//   `hasMore` flips off when the server returns the last page.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/comment.dart';
import 'package:kamos/core/models/page.dart' as models;
import 'package:kamos/features/comments/providers/comment_providers.dart';
import 'package:kamos/features/comments/repository/comment_repository.dart';

class _StubRepo implements CommentRepository {
  _StubRepo({required this.pages});

  /// Successive pages returned by `list()` — call N → pages[N].
  final List<models.Page<Comment>> pages;

  int listCalls = 0;
  int createCalls = 0;
  String? lastCursor;
  String? lastBody;

  @override
  Future<models.Page<Comment>> list(String checkInId, {String? cursor}) async {
    lastCursor = cursor;
    final p = pages[listCalls];
    listCalls += 1;
    return p;
  }

  @override
  Future<Comment> create({
    required String checkInId,
    required String body,
  }) async {
    createCalls += 1;
    lastBody = body;
    return Comment(
          id: 'cm-D',
          checkInId: checkInId,
          user: const CheckinUser(
            id: 'u-self',
            username: 'self',
            displayUsername: 'self',
            displayName: 'self',
          ),
          body: body,
          createdAt: '2026-05-04T00:00:00Z',
        );
  }

  @override
  Future<void> deleteOwn(String commentId) async {}
}

Comment _c(String id) => Comment(
      id: id,
      checkInId: 'ci42',
      user: const CheckinUser(
        id: 'u-other',
        username: 'other',
        displayUsername: 'other',
        displayName: 'other',
      ),
      body: id,
      createdAt: '2026-05-01T00:00:00Z',
    );

void main() {
  group('CommentsNotifier', () {
    test('build emits items in repository order with cursor + hasMore',
        () async {
      final repo = _StubRepo(pages: [
        models.Page<Comment>(
          items: [_c('A'), _c('B'), _c('C')],
          nextCursor: 'tok',
          hasMore: true,
        ),
      ]);
      final container = ProviderContainer(overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final state =
          await container.read(commentsProvider('ci42').future);

      expect(state.items.map((c) => c.id).toList(), ['A', 'B', 'C']);
      expect(state.nextCursor, 'tok');
      expect(state.hasMore, isTrue);
    });

    test('optimistic post prepends the created comment (DESC order)',
        () async {
      final repo = _StubRepo(pages: [
        models.Page<Comment>(
          items: [_c('A'), _c('B'), _c('C')],
          nextCursor: 'tok',
          hasMore: true,
        ),
      ]);
      final container = ProviderContainer(overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Wait for the initial load.
      await container.read(commentsProvider('ci42').future);

      // Post a new comment.
      final created = await container
          .read(commentsProvider('ci42').notifier)
          .post('Just posted');

      final after = container.read(commentsProvider('ci42')).asData!.value;
      expect(after.items.map((c) => c.id).toList(),
          [created.id, 'A', 'B', 'C']);
      // Server-confirmed comment is at the head.
      expect(after.items.first.id, 'cm-D');
      expect(after.items.first.body, 'Just posted');
      expect(repo.lastBody, 'Just posted');
    });

    test('loadMore appends older comments and updates hasMore', () async {
      final repo = _StubRepo(pages: [
        models.Page<Comment>(
          items: [_c('A'), _c('B'), _c('C')],
          nextCursor: 'tok',
          hasMore: true,
        ),
        models.Page<Comment>(
          items: [_c('D'), _c('E')],
          hasMore: false,
        ),
      ]);
      final container = ProviderContainer(overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(commentsProvider('ci42').future);

      await container.read(commentsProvider('ci42').notifier).loadMore();

      final after = container.read(commentsProvider('ci42')).asData!.value;
      expect(after.items.map((c) => c.id).toList(),
          ['A', 'B', 'C', 'D', 'E']);
      expect(after.hasMore, isFalse);
      expect(after.nextCursor, isNull);
      expect(repo.listCalls, 2);
      expect(repo.lastCursor, 'tok');
    });
  });
}
