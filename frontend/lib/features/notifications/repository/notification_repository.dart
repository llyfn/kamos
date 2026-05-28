// KAMOS — NotificationRepository (SPEC §5.4).
//
// Wraps the three notification endpoints:
//
//   GET  /v1/notifications                cursor-paged, 20/page
//   POST /v1/notifications/read           ids OR all (exactly one)
//   GET  /v1/notifications/unread-count   feeds the bottom-tab dot
//
// `markRead` accepts either a non-empty `ids` list OR `all: true` — exactly
// one path; the server returns 422 if both or neither are supplied. The
// response carries the rowcount of actually-transitioned rows.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/page.dart' as models;
import '../models/notification.dart';

class NotificationRepository {
  NotificationRepository(Dio dio) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<models.Page<KamosNotification>> list({
    String? cursor,
    int limit = 20,
  }) async {
    final data = await _api.notifications.list(cursor: cursor, limit: limit);
    return models.Page<KamosNotification>.fromJson(
      data,
      (e) => KamosNotification.fromJson(e as Map<String, dynamic>),
    );
  }

  /// Marks specific rows by id. Returns the count actually transitioned to
  /// read (rows already read, or not owned by the caller, are silently
  /// skipped server-side). A no-op when [ids] is empty.
  Future<int> markRead(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final data = await _api.notifications.markRead(ids: ids);
    return (data['marked'] as num?)?.toInt() ?? 0;
  }

  /// Marks every unread row read for the authed user.
  Future<int> markAllRead() async {
    final data = await _api.notifications.markRead(all: true);
    return (data['marked'] as num?)?.toInt() ?? 0;
  }

  Future<int> unreadCount() async {
    final data = await _api.notifications.unreadCount();
    return (data['count'] as num?)?.toInt() ?? 0;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);
