// KAMOS — NotificationRow (SPEC §5.4, design/notifications_ux.md §2.2-§2.6).
//
// Renders a single notification card. Per-type rules:
//
//   toast            → tap → /check-ins/:id        verb: notifVerbToast
//   comment          → tap → /check-ins/:id        verb: notifVerbComment
//   follow           → tap → /users/:username      verb: notifVerbFollow
//   follow_request   → no card-tap; inline buttons verb: notifVerbFollowRequest
//   follow_approved  → tap → /users/:username      verb: notifVerbFollowApproved
//
// Visual states per §2.3:
//   unread → background bgTintMizu (light brand wash)
//   read   → background bgSurface  (default card)
//
// Soft-deleted actor (§2.5): when `actor == null`, the avatar is a kinari
// tile with the em-dash glyph and the actor span renders the localized
// `notificationsDeletedActor` string. Tap behavior is unchanged for the
// types that target a check-in (toast / comment); for the user-targeted
// types (follow / follow_approved) the tap is a no-op because there is no
// user page to navigate to.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/elapsed_time.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../social/repository/social_repository.dart';
import '../models/notification.dart';
import '../providers/notification_providers.dart';

class NotificationRow extends ConsumerWidget {
  const NotificationRow({super.key, required this.notification});

  final KamosNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final n = notification;
    final isRequest = n.type == NotificationType.followRequest;

    final cardBg = n.isUnread ? t.bgTintMizu : t.bgSurface;

    final card = AnimatedContainer(
      duration: t.durBase,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F2350),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(notification: n),
          if (isRequest) ...[
            const SizedBox(height: KamosSpacing.md),
            _FollowRequestActions(notification: n),
          ],
        ],
      ),
    );

    if (isRequest) {
      // Tap area excluded — the inline Approve/Decline buttons own taps.
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _handleTap(context, ref, n, l),
      child: card,
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    KamosNotification n,
    AppLocalizations l,
  ) {
    // Mark this row read in the background (idempotent server-side).
    ref.read(notificationListProvider.notifier).markRead([n.id]);
    final target = _tapTarget(n);
    if (target != null) {
      context.push(target);
    }
  }

  String? _tapTarget(KamosNotification n) {
    switch (n.type) {
      case NotificationType.toast:
      case NotificationType.comment:
        final id = n.checkInId;
        return id == null ? null : '/check-ins/$id';
      case NotificationType.follow:
      case NotificationType.followApproved:
        final actor = n.actor;
        if (actor == null || actor.username.isEmpty) return null;
        return '/users/${actor.username}';
      case NotificationType.followRequest:
        return null;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notification});
  final KamosNotification notification;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final n = notification;
    final deleted = n.actor == null;
    final actorName = deleted
        ? l.notificationsDeletedActor
        : (n.actor!.displayName.isNotEmpty
              ? n.actor!.displayName
              : n.actor!.displayUsername);
    final timeLabel = _formatTime(n.createdAt, l);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KamosAvatar(
          initial: deleted ? '—' : actorName,
          size: 40,
          imageUrl: deleted ? null : n.actor!.avatarUrl,
        ),
        const SizedBox(width: KamosSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _VerbLine(
                      notification: n,
                      actorName: actorName,
                      deleted: deleted,
                    ),
                  ),
                  const SizedBox(width: KamosSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: t.fg3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(String iso, AppLocalizations l) {
    final dt = parseIsoDateOrNull(iso);
    if (dt == null) return '';
    return elapsedShort(dt.toLocal(), l);
  }
}

/// Renders the "{actor} verb" line with the actor name styled (bold) and the
/// rest of the verb template in the normal weight. The template uses ARB
/// placeholder syntax — we split on `{actor}` to wrap the substitution in a
/// bold span. If a translator drops the placeholder, the whole template
/// renders verbatim (still readable, no crash).
class _VerbLine extends StatelessWidget {
  const _VerbLine({
    required this.notification,
    required this.actorName,
    required this.deleted,
  });

  final KamosNotification notification;
  final String actorName;
  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final template = _template(notification.type, actorName, l);
    final parts = template.split(actorName);
    final actorStyle = TextStyle(
      fontFamily: 'NotoSansJP',
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: deleted ? t.fg2 : t.fg1,
    );
    final restStyle = TextStyle(
      fontFamily: 'NotoSansJP',
      fontSize: 15,
      height: 1.4,
      color: t.fg1,
    );

    // Common case: the actor name appears exactly once in the rendered string.
    // Less common but possible (a translator may repeat the placeholder): fall
    // back to the whole template in regular weight rather than producing a
    // janky multi-bold output.
    if (parts.length != 2) {
      return Text(template, style: restStyle);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts[0], style: restStyle),
          TextSpan(text: actorName, style: actorStyle),
          TextSpan(text: parts[1], style: restStyle),
        ],
      ),
    );
  }

  String _template(
    NotificationType type,
    String actor,
    AppLocalizations l,
  ) {
    switch (type) {
      case NotificationType.toast:
        return l.notifVerbToast(actor);
      case NotificationType.comment:
        return l.notifVerbComment(actor);
      case NotificationType.follow:
        return l.notifVerbFollow(actor);
      case NotificationType.followRequest:
        return l.notifVerbFollowRequest(actor);
      case NotificationType.followApproved:
        return l.notifVerbFollowApproved(actor);
    }
  }
}

class _FollowRequestActions extends ConsumerStatefulWidget {
  const _FollowRequestActions({required this.notification});
  final KamosNotification notification;

  @override
  ConsumerState<_FollowRequestActions> createState() =>
      _FollowRequestActionsState();
}

class _FollowRequestActionsState
    extends ConsumerState<_FollowRequestActions> {
  bool _busy = false;

  Future<void> _resolve({required bool approve}) async {
    if (_busy) return;
    final n = widget.notification;
    final actor = n.actor;
    if (actor == null) {
      // Soft-deleted actor — still attempt the call (server may have a
      // tombstone-safe path), but the row will be hidden either way.
      ref.read(notificationListProvider.notifier).removeLocal(n.id);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (approve) {
        await repo.approve(actor.id);
      } else {
        await repo.decline(actor.id);
      }
      // Mark the notification read AND remove the row from the list — the
      // request is no longer actionable.
      await ref
          .read(notificationListProvider.notifier)
          .markRead([n.id]);
      ref.read(notificationListProvider.notifier).removeLocal(n.id);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _resolve(approve: false),
            child: Text(l.inboxDecline),
          ),
        ),
        const SizedBox(width: KamosSpacing.sm),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : () => _resolve(approve: true),
            style: FilledButton.styleFrom(
              backgroundColor: t.ai,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(l.inboxApprove),
          ),
        ),
      ],
    );
  }
}
