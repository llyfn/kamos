// KAMOS — CommentRepository (Phase 6).
//
// Wraps the three comment endpoints:
//
//   GET    /v1/check-ins/{id}/comments    OptionalAuth, public visibility rules
//   POST   /v1/check-ins/{id}/comments    authed
//   DELETE /v1/comments/{id}              authed; own or admin
//
// The list endpoint is NOT cursor-paginated in the OpenAPI delta — the server
// returns the full visible list in chronological order (oldest first). If
// that changes, this method will need to grow a cursor parameter.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/models/comment.dart';
import '../exceptions.dart';

class CommentRepository {
  CommentRepository(this._dio);
  final Dio _dio;

  Future<List<Comment>> list(String checkInId) async {
    final res = await _dio.get('/v1/check-ins/$checkInId/comments');
    final data = res.data;
    final items = data is Map<String, dynamic>
        ? (data['items'] as List?) ?? const []
        : (data as List?) ?? const [];
    return items
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Comment> create({
    required String checkInId,
    required String body,
  }) async {
    if (body.length > 500) {
      throw const CommentTooLongException();
    }
    final res = await _dio.post(
      '/v1/check-ins/$checkInId/comments',
      data: {'body': body},
    );
    return Comment.fromJson(res.data as Map<String, dynamic>);
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
