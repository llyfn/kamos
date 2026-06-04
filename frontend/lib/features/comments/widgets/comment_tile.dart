// KAMOS — Single comment row.
//
// Renders avatar + username + body + relative timestamp. The trailing delete
// affordance is rendered only when the comment author's id matches the
// signed-in user's id (read from `meProvider`). If `meProvider` is not in the
// data state yet, the delete icon is hidden — when the user signs back in or
// the profile loads, the rebuild adds the icon.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/comment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../../users/navigation.dart';

class CommentTile extends ConsumerWidget {
  const CommentTile({super.key, required this.comment, required this.onDelete});

  final Comment comment;

  /// Called with the comment id when the user confirms a delete.
  final Future<void> Function(String commentId) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final me = ref.watch(meProvider).asData?.value;
    // Stage 7 (M-12.2): comment.user can be null when the original author
    // was hard-purged (migration 013 sets comments.user_id ON DELETE SET
    // NULL). isOwn is false for orphaned rows — only moderator+ can
    // delete them and that surface lives in the admin React client.
    final author = comment.user;
    final isOwn = me != null && author != null && me.user.id == author.id;
    final displayName = author?.displayUsername ?? l.commentAuthorDeleted;
    final when = parseIsoDateOrNull(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KamosSpacing.lg,
        vertical: KamosSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar taps through to the author's profile. Orphan comments
          // (author hard-purged) have a null `author` and no tappable
          // target — fall back to a plain avatar with no gesture.
          author != null
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => pushUserProfile(context, author.username),
                  child: KamosAvatar(
                    initial: displayName,
                    size: 32,
                    imageUrl: author.avatarUrl,
                  ),
                )
              : KamosAvatar(
                  initial: displayName,
                  size: 32,
                  imageUrl: author?.avatarUrl,
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // Username Text also taps through to the author's
                      // profile. Orphan comments render the placeholder
                      // label without a gesture.
                      child: author != null
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  pushUserProfile(context, author.username),
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: t.fg1,
                                ),
                              ),
                            )
                          : Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.fg1,
                              ),
                            ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (when != null)
                          Text(
                            elapsedShort(when, l),
                            style: TextStyle(fontSize: 11, color: t.fg3),
                          ),
                        if (isOwn)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Tooltip(
                              message: l.commentsDelete,
                              child: InkWell(
                                onTap: () => _confirmAndDelete(context, l),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 14,
                                    color: t.fg3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: TextStyle(fontSize: 14, height: 1.5, color: t.fg1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.commentsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commentsDelete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await onDelete(comment.id);
    }
  }
}
