// KAMOS — Single comment row.
//
// Renders avatar + username + body + relative timestamp. When the viewer is
// the author, a small `more_horiz` icon sits to the right of the body and
// opens a bottom sheet with Edit and Delete actions — mirroring the own-
// check-in overflow pattern in `CheckInCard`. Edit swaps the body Text into
// an inline TextField with Save / Cancel; Delete confirms then calls the
// `onDelete` callback. Soft-deleted-author rows (`comment.user == null`)
// have no isOwn predicate so the menu is hidden.

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

  Future<void> _openOwnerMenu() async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.commentEdit),
              onTap: () => Navigator.pop(sheetCtx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.commentsDelete),
              onTap: () => Navigator.pop(sheetCtx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      _enterEdit();
    } else if (action == 'delete') {
      await _confirmAndDelete(context, l);
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
                  children: [
                    // Username Text also taps through to the author's
                    // profile. Orphan comments render the placeholder
                    // label without a gesture.
                    Expanded(
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
                    if (when != null) ...[
                      const SizedBox(width: 6),
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
          if (isOwn && !_editing)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: InkWell(
                onTap: _openOwnerMenu,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz, size: 18, color: t.fg3),
                ),
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
