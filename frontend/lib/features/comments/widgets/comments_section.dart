// KAMOS — Comments section.
//
// Composite: section header + list (or empty/error/loading state) + composer.
// Designed to be embedded inside a check-in detail screen. Handles the
// optimistic-post and optimistic-delete error paths by surfacing a SnackBar.
//
// Server-side ordering is DESC (newest first). The list is rendered head-first
// (newest at top), and when there are more older comments to fetch a "load
// earlier comments" affordance appears at the BOTTOM of the list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/state_views.dart';
import '../providers/comment_providers.dart';
import 'comment_composer.dart';
import 'comment_tile.dart';

class CommentsSection extends ConsumerWidget {
  const CommentsSection({super.key, required this.checkInId});
  final String checkInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(commentsProvider(checkInId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KamosSpacing.lg,
            KamosSpacing.lg,
            KamosSpacing.lg,
            KamosSpacing.xs,
          ),
          child: Text(
            l.commentsTitle,
            style: TextStyle(
              fontFamily: 'ShipporiMincho',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: t.fg1,
            ),
          ),
        ),
        AsyncWidget(
          value: async,
          errorMessage: l.commentsLoadFailed,
          onRetry: () =>
              ref.read(commentsProvider(checkInId).notifier).refresh(),
          data: (s) {
            if (s.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: KamosSpacing.sm),
                child: EmptyView(title: l.commentsEmpty),
              );
            }
            return Column(
              children: [
                for (final c in s.items)
                  CommentTile(
                    comment: c,
                    onDelete: (id) => _delete(context, ref, l, id),
                  ),
                if (s.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KamosSpacing.sm),
                    child: TextButton(
                      onPressed: s.isLoadingMore
                          ? null
                          : () => ref
                                .read(commentsProvider(checkInId).notifier)
                                .loadMore(),
                      child: s.isLoadingMore
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.commentsLoadEarlier),
                    ),
                  ),
              ],
            );
          },
        ),
        const Divider(height: 1),
        CommentComposer(onSubmit: (body) => _submit(context, ref, l, body)),
      ],
    );
  }

  Future<bool> _submit(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String body,
  ) async {
    try {
      await ref.read(commentsProvider(checkInId).notifier).post(body);
      return true;
    } on CommentTooLongException {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.commentsTooLong)));
      }
      return false;
    } on CommentInvalidBodyException {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.commentsInvalidBody)));
      }
      return false;
    } on CommentRateLimitedException {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.commentsRateLimited)));
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.commentsPostFailed)));
      }
      return false;
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String commentId,
  ) async {
    try {
      await ref.read(commentsProvider(checkInId).notifier).deleteOwn(commentId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorGeneric)));
      }
    }
  }
}
