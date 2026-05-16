// KAMOS — Comments section (Phase 6).
//
// Composite: section header + list (or empty/error/loading state) + composer.
// Designed to be embedded inside a check-in detail screen. Handles the
// optimistic-post and optimistic-delete error paths by surfacing a SnackBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../exceptions.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
        async.when(
          loading: () => LoadingView(label: l.loadingLabel),
          error: (_, _) => ErrorView(
            message: l.commentsLoadFailed,
            onRetry: () =>
                ref.read(commentsProvider(checkInId).notifier).refresh(),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: EmptyView(title: l.commentsEmpty),
              );
            }
            return Column(
              children: [
                for (final c in comments)
                  CommentTile(
                    comment: c,
                    onDelete: (id) => _delete(context, ref, l, id),
                  ),
              ],
            );
          },
        ),
        const Divider(height: 1),
        CommentComposer(
          onSubmit: (body) => _submit(context, ref, l, body),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.commentsTooLong)),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.commentsPostFailed)),
        );
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
      await ref
          .read(commentsProvider(checkInId).notifier)
          .deleteOwn(commentId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorGeneric)),
        );
      }
    }
  }
}
