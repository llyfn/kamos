// KAMOS — CheckInRepository.
//
// Implements the real 3-step photo upload flow against the backend:
//
//   1. POST  /v1/uploads/photo-presign            (auth) → presign response
//   2. PUT   <upload_url>                         (no auth — URL is signed)
//      body: file bytes, headers: server-supplied (incl. Content-Type)
//   3. POST  /v1/check-ins/{id}/photos            (auth) → { id, url }
//
// Notes:
// * The PUT runs through a separate Dio instance with NO interceptors. The
//   auth interceptor must not attach a Bearer header (the presigned URL signs
//   the request itself) and a 401 from the storage provider must not trigger
//   the refresh loop.
// * `onProgress` reports the PUT progress (0.0 → 1.0). Phases 1 and 3 are
//   not part of the bar, but they normally complete in tens of ms.
// * Backend may answer presign 503 with `code: STORAGE_DISABLED` when R2 is
//   not configured. That surfaces as a `StorageDisabledException` so the
//   screen can show a friendly "saved without photos" message instead of a
//   generic "Could not post" toast.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';

// The repository's typed exception family lives in
// `core/api/api_exceptions.dart`. Re-export the two photo-upload symbols so
// existing callers and tests that import them via this file (`package:kamos/
// features/check_in/repository/checkin_repository.dart`) keep working.
export '../../../core/api/api_exceptions.dart'
    show StorageDisabledException, PhotoUploadException;

/// Allowed image MIME types for the presign endpoint. HEIC and friends must
/// be converted upstream (image_picker on iOS auto-converts to JPEG).
const _allowedContentTypes = {'image/jpeg', 'image/png', 'image/webp'};

class CheckInRepository {
  CheckInRepository({required this.dio, Dio? rawDio})
    : _rawDio = rawDio ?? Dio();

  final Dio dio;

  /// Bare Dio for the presigned PUT. No interceptors, no Authorization header.
  /// The presigned URL signs the request itself.
  final Dio _rawDio;

  Future<Checkin> create({
    required String beverageId,
    double? rating,
    String? review,
    List<String> tags = const [],
    List<String> photos = const [],
    Price? price,
    String? purchaseType,
    String? servingStyle,
    Map<String, dynamic>? venue,
  }) async {
    final res = await dio.post(
      '/v1/check-ins',
      data: {
        'beverage_id': beverageId,
        'rating': ?rating,
        if (review != null && review.isNotEmpty) 'review': review,
        if (tags.isNotEmpty) 'tags': tags,
        if (photos.isNotEmpty) 'photos': photos,
        'price': ?price?.toJson(),
        'purchase_type': ?purchaseType,
        'serving_style': ?servingStyle,
        if (venue != null && venue.isNotEmpty) 'venue': venue,
      },
    );
    return Checkin.fromJson(res.data as Map<String, dynamic>);
  }

  /// Fetches a single check-in by id for the detail screen. The endpoint
  /// is OptionalAuth on the server side; signed-out users still get a
  /// response gated by the check-in's visibility rules.
  Future<Checkin> getOne(String id) async {
    final res = await dio.get('/v1/check-ins/$id');
    return Checkin.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<FlavorTag>> tags() async {
    final res = await dio.get('/v1/flavor-tags');
    final raw = (res.data as List?) ?? const [];
    return raw
        .map((e) => FlavorTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Three-step photo upload: presign → PUT → attach.
  ///
  /// Throws:
  /// * [StorageDisabledException] if the presign endpoint returns 503 with
  ///   `code: STORAGE_DISABLED`.
  /// * [PhotoUploadException] for any other failure in the chain.
  Future<PhotoRef> uploadPhotoAndAttach({
    required String checkInId,
    required File file,
    required void Function(double pct) onProgress,
  }) async {
    final contentType = _contentTypeForPath(file.path);
    if (!_allowedContentTypes.contains(contentType)) {
      throw PhotoUploadException(
        'Unsupported content type: $contentType',
        stage: 'presign',
      );
    }
    final byteSize = await file.length();

    // Step 1: presign.
    final Map<String, dynamic> presign;
    try {
      final res = await dio.post(
        '/v1/uploads/photo-presign',
        data: {'content_type': contentType, 'byte_size': byteSize},
      );
      presign = res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      if (status == 503 && body is Map<String, dynamic>) {
        final code =
            (body['code'] as String?) ??
            (e.error is ApiException ? (e.error as ApiException).code : '');
        if (code == 'STORAGE_DISABLED') {
          throw const StorageDisabledException();
        }
      }
      // Also handle the case where AuthInterceptor wrapped the error: it
      // copies `code` into ApiException, with the 503 status preserved.
      if (e.error is ApiException) {
        final api = e.error as ApiException;
        if (api.statusCode == 503 && api.code == 'STORAGE_DISABLED') {
          throw const StorageDisabledException();
        }
      }
      throw PhotoUploadException(
        e.message ?? 'presign failed',
        stage: 'presign',
      );
    }

    final uploadId = presign['upload_id'] as String?;
    final uploadUrl = presign['upload_url'] as String?;
    final headersAny = presign['headers'];
    if (uploadId == null ||
        uploadId.isEmpty ||
        uploadUrl == null ||
        uploadUrl.isEmpty) {
      throw const PhotoUploadException(
        'presign response missing upload_id or upload_url',
        stage: 'presign',
      );
    }
    final headers = <String, dynamic>{};
    if (headersAny is Map) {
      headers.addAll(headersAny.map((k, v) => MapEntry(k.toString(), v)));
    }
    // R2 requires Content-Type to match what was signed. Backend should
    // already include it in `headers`; fall back if it didn't.
    headers.putIfAbsent('Content-Type', () => contentType);

    // Step 2: PUT bytes through the raw Dio (no auth interceptor).
    try {
      await _rawDio.put<dynamic>(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            ...headers,
            // Dio will not stream chunked without an explicit length.
            Headers.contentLengthHeader: byteSize,
          },
          // Raw bytes — Dio's JSON content-type default would otherwise
          // poison the request.
          contentType: contentType,
          // Accept 200/204; anything else is an error.
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          final pct = sent / total;
          onProgress(pct.clamp(0.0, 1.0));
        },
      );
    } on DioException catch (e) {
      throw PhotoUploadException(
        e.message ?? 'upload PUT failed',
        stage: 'put',
      );
    }

    // Step 3: attach the upload to the check-in.
    final Map<String, dynamic> attachBody;
    try {
      final res = await dio.post(
        '/v1/check-ins/$checkInId/photos',
        data: {'upload_id': uploadId},
      );
      attachBody = res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw PhotoUploadException(e.message ?? 'attach failed', stage: 'attach');
    }

    return PhotoRef.fromJson(attachBody);
  }

  /// Best-effort MIME from extension. `image_picker` does not always include
  /// the MIME, but the on-disk extension is stable enough for the 3 types we
  /// allow.
  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'application/octet-stream';
  }
}

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => CheckInRepository(dio: ref.read(dioProvider)),
);
