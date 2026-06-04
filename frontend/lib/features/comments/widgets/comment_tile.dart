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
import '../providers/comment_providers.dart';

class CommentTile extends ConsumerStatefulWidget {
  const CommentTile({super.key, required this.comment, required this.onDelete});

  final Comment comment;

  /// Called with the comment id when the user confirms a delete.
  final Future<void> Function(String commentId) onDelete;

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.body);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _enterEdit() {
    setState(() {
      _editController.text = widget.comment.body;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    if (_saving) return;
    final newBody = _editController.text.trim();
    if (newBody.isEmpty || newBody.length > 500) return;
    if (newBody == widget.comment.body) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(commentsProvider(widget.comment.checkInId).notifier)
          .edit(commentId: widget.comment.id, body: newBody);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                elapsedShort(when, l),
                                style: TextStyle(fontSize: 11, color: t.fg3),
                              ),
                              if (comment.editedAt != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  l.editedMarker,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: t.fg3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (isOwn && !_editing)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Tooltip(
                              message: l.commentEdit,
                              child: InkWell(
                                onTap: _enterEdit,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: t.fg3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (isOwn && !_editing)
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
                if (_editing) ...[
                  TextField(
                    controller: _editController,
                    maxLength: 500,
                    autofocus: true,
                    maxLines: null,
                    style: TextStyle(fontSize: 14, height: 1.5, color: t.fg1),
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _cancelEdit,
                        child: Text(l.actionCancel),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _saving ? null : _saveEdit,
                        child: Text(l.actionSave),
                      ),
                    ],
                  ),
                ] else
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
      await widget.onDelete(widget.comment.id);
    }
  }
}
