// KAMOS — CommentRepository.
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
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/comment.dart';
import '../../../core/models/page.dart' as models;

/// Wraps the `comments` tag of [KamosApi] (list / create / delete) and
/// lifts `DioException`s into the typed comment exceptions in
/// `core/api/api_exceptions.dart`. Used by the comments feature's
/// providers and widgets.
class CommentRepository {
  CommentRepository(Dio dio) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<models.Page<Comment>> list(String checkInId, {String? cursor}) async {
    final data = await _api.comments.list(checkInId, cursor: cursor);
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
  static final RegExp _controlCharRegex = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

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
      final data = await _api.comments.create(
        checkInId: checkInId,
        body: body,
      );
      return Comment.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const CommentRateLimitedException();
      }
      rethrow;
    }
  }

  /// Slice 01 / SPEC §5.4 — author-only PATCH of the comment body. Mirrors
  /// the create-side sanitization (1..500 chars, no C0 control characters).
  /// 404 from the server is normalized to [CommentDeletedException].
  Future<Comment> edit({
    required String commentId,
    required String body,
  }) async {
    if (body.length > 500) {
      throw const CommentTooLongException();
    }
    if (_controlCharRegex.hasMatch(body)) {
      throw const CommentInvalidBodyException();
    }
    try {
      final data = await _api.comments.update(
        commentId: commentId,
        body: body,
      );
      return Comment.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      String code = '';
      final responseBody = e.response?.data;
      if (responseBody is Map<String, dynamic>) {
        code = (responseBody['code'] as String?) ?? '';
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

  Future<void> deleteOwn(String commentId) async {
    try {
      await _api.comments.deleteOne(commentId);
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
  (ref) => CommentRepository(ref.watch(dioProvider)),
);
