// KAMOS — Notification model (SPEC §5.4).
//
// Mirrors the OpenAPI `Notification` schema. The `actor` field is nullable
// because the FK is ON DELETE SET NULL — when the original actor has been
// hard-deleted by the username-hold sweep, the row survives and the UI
// renders a localized "Deleted user" placeholder.
//
// `check_in_id` / `comment_id` are present only for the types that carry the
// matching source reference (`toast`, `comment`); they are absent for the
// three `follow*` types. Both are also nullable for the soft-delete case
// where the referenced check-in itself was removed.
//
// Type comes off the wire as a string — we map to a Dart enum so switches in
// widgets are exhaustive. Unknown strings fall back to [NotificationType.toast]
// rather than throwing; the server-side enum is closed but the client must
// not crash on a forward-compat value.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/beverage.dart';

part 'notification.freezed.dart';

/// Notification type. Mirrors OpenAPI `Notification.type` enum.
enum NotificationType {
  toast,
  comment,
  follow,
  followRequest,
  followApproved;

  /// Wire value (snake_case, matches the OpenAPI enum entries).
  String get wire => switch (this) {
    NotificationType.toast => 'toast',
    NotificationType.comment => 'comment',
    NotificationType.follow => 'follow',
    NotificationType.followRequest => 'follow_request',
    NotificationType.followApproved => 'follow_approved',
  };

  /// Parses the wire value, defaulting to [NotificationType.toast] when the
  /// server emits an unknown value (forward-compat safety; the row still
  /// renders rather than crashing the page).
  static NotificationType fromWire(String raw) => switch (raw) {
    'toast' => NotificationType.toast,
    'comment' => NotificationType.comment,
    'follow' => NotificationType.follow,
    'follow_request' => NotificationType.followRequest,
    'follow_approved' => NotificationType.followApproved,
    _ => NotificationType.toast,
  };
}

@Freezed(fromJson: false, toJson: false)
abstract class KamosNotification with _$KamosNotification {
  const factory KamosNotification({
    required String id,
    required NotificationType type,
    CheckinUser? actor,
    String? checkInId,
    String? commentId,
    String? readAt,
    @Default('') String createdAt,
  }) = _KamosNotification;

  factory KamosNotification.fromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    return KamosNotification(
      id: (json['id'] as String?) ?? '',
      type: NotificationType.fromWire((json['type'] as String?) ?? ''),
      actor: actorJson is Map<String, dynamic>
          ? CheckinUser.fromJson(actorJson)
          : null,
      checkInId: json['check_in_id'] as String?,
      commentId: json['comment_id'] as String?,
      readAt: json['read_at'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

extension KamosNotificationX on KamosNotification {
  bool get isUnread => readAt == null;
}
