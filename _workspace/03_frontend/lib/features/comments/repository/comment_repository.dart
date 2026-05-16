// KAMOS — CommentRepository (Phase 6).
//
// Wraps the three comment endpoints:
//
//   GET    /v1/check-ins/{id}/comments    OptionalAuth, public visibility rules
//   POST   /v1/check-ins/{id}/comments    authed
//   DELETE /v1/comments/{id}              authed; own or admin
//
// The list endpoint is cursor-paginated (`PageOfComment`) and ordered
// most-recent-first server-side (`ORDER BY created_at DESC, id DESC`). The
// `list` method threads an optional `cursor` and returns the full `Page<T>`
// envelope so callers can paginate older comments downward.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/models/comment.dart';
import '../../../core/models/page.dart' as models;
import '../exceptions.dart';

class CommentRepository {
  CommentRepository(this._dio);
  final Dio _dio;

  Future<models.Page<Comment>> list(
    String checkInId, {
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/v1/check-ins/$checkInId/comments',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      return const models.Page<Comment>(items: [], hasMore: false);
    }
    return models.Page<Comment>.fromJson(
      data,
      (e) => Comment.fromJson(e as Map<String, dynamic>),
    );
  }

  /// Rejects C0 control bytes except `\t` (0x09) and `\n` (0x0A); also rejects
  /// DEL (0x7F). Mirrors the server-side filter (`openapi.yaml` `Comment.body`)
  /// and the beverage-request feature's input formatter — clients catch this
  /// locally so the UI can show `commentsInvalidBody` rather than the generic
  /// failure toast.
  static final RegExp _controlCharRegex =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  Future<Comment> create({
    required String checkInId,
    required String body,
  }) async {
    if (body.length > 500) {
      throw const CommentTooLongException();
    }
    if (_controlCharRegex.hasMatch(body)) {
      throw const CommentInvalidBodyException();
    }
    try {
      final res = await _dio.post(
        '/v1/check-ins/$checkInId/comments',
        data: {'body': body},
      );
      return Comment.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const CommentRateLimitedException();
      }
      rethrow;
    }
  }

  Future<void> deleteOwn(String commentId) async {
    try {
      await _dio.delete('/v1/comments/$commentId');
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      String code = '';
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        code = (body['code'] as String?) ?? '';
      }
      if (code.isEmpty && e.error is ApiException) {
        code = (e.error as ApiException).code;
      }
      if (status == 403) {
        throw const CommentForbiddenException();
      }
      if (status == 404 || code == 'COMMENT_DELETED') {
        throw const CommentDeletedException();
      }
      rethrow;
    }
  }
}

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(ref.read(dioProvider)),
);
