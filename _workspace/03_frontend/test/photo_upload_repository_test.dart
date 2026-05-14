// KAMOS — CheckInRepository.uploadPhotoAndAttach tests.
//
// Drives the 3-step presign → PUT → attach flow against custom Dio adapters.
// Two adapters: one for the auth-bearing API (handles presign + attach), one
// raw adapter for the presigned PUT (must NOT see Authorization).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/checkin.dart';
import 'package:kamos/features/check_in/repository/checkin_repository.dart';

const _presignBody = {
  'upload_id': 'upl-1234',
  'upload_url': 'https://r2.test/objects/abc.jpg?sig=mock',
  'headers': {
    'Content-Type': 'image/jpeg',
    'x-amz-acl': 'private',
  },
  'blob_key': 'check-ins/abc.jpg',
  'expires_at': '2026-05-14T12:00:00Z',
};

const _attachBody = {
  'id': 'pho-1',
  'url': 'https://cdn.test/objects/abc.jpg',
};

/// Adapter for the auth-bearing API. Answers `/v1/uploads/photo-presign` and
/// `/v1/check-ins/{id}/photos`. Tracks how many times each was called and
/// optionally overrides the presign response.
class _ApiAdapter implements HttpClientAdapter {
  _ApiAdapter({
    this.presignStatus = 200,
    this.presignResponse = _presignBody,
  });

  final int presignStatus;
  final Map<String, dynamic> presignResponse;

  int presignCalls = 0;
  int attachCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.endsWith('/v1/uploads/photo-presign')) {
      presignCalls += 1;
      return ResponseBody.fromString(
        jsonEncode(presignResponse),
        presignStatus,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (path.contains('/v1/check-ins/') && path.endsWith('/photos')) {
      attachCalls += 1;
      return ResponseBody.fromString(
        jsonEncode(_attachBody),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('not found', 404);
  }
}

/// Adapter for the raw (presigned) PUT. Answers `r2.test`. Records whether the
/// Authorization header was present (it must not be) and how many bytes flowed.
class _PutAdapter implements HttpClientAdapter {
  _PutAdapter({this.status = 200});
  final int status;
  bool sawAuthHeader = false;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (options.headers.containsKey('Authorization')) {
      sawAuthHeader = true;
    }
    // Drain the body stream so onSendProgress fires before the response.
    if (requestStream != null) {
      await for (final _ in requestStream) {
        // ignore
      }
    }
    return ResponseBody.fromString('', status);
  }
}

/// Writes [bytes] to a fresh temp .jpg and returns the absolute path.
Future<File> _tempJpeg(List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('kamos_test_');
  final f = File('${dir.path}/photo.jpg');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}

void main() {
  group('CheckInRepository.uploadPhotoAndAttach', () {
    test('happy path: presign → PUT → attach returns PhotoRef and reports progress',
        () async {
      final apiAdapter = _ApiAdapter();
      final putAdapter = _PutAdapter();

      final apiDio = Dio(BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ))
        ..httpClientAdapter = apiAdapter;
      final rawDio = Dio()..httpClientAdapter = putAdapter;

      final repo = CheckInRepository(dio: apiDio, rawDio: rawDio);
      final file = await _tempJpeg(List.filled(2048, 0));

      final progress = <double>[];
      final result = await repo.uploadPhotoAndAttach(
        checkInId: 'chk-1',
        file: file,
        onProgress: progress.add,
      );

      expect(result, isA<PhotoRef>());
      expect(result.id, 'pho-1');
      expect(result.url, 'https://cdn.test/objects/abc.jpg');
      expect(apiAdapter.presignCalls, 1);
      expect(apiAdapter.attachCalls, 1);
      expect(putAdapter.calls, 1);
      expect(putAdapter.sawAuthHeader, isFalse,
          reason: 'raw Dio must not send Authorization to the presigned URL');
      expect(
        progress.any((p) => p > 0.0 && p <= 1.0),
        isTrue,
        reason: 'onProgress should fire at least once with a value in (0, 1]',
      );
    });

    test('503 STORAGE_DISABLED surfaces StorageDisabledException', () async {
      final apiAdapter = _ApiAdapter(
        presignStatus: 503,
        presignResponse: const {
          'error': 'photo storage unavailable',
          'code': 'STORAGE_DISABLED',
        },
      );
      final putAdapter = _PutAdapter();

      final apiDio = Dio(BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ))
        ..httpClientAdapter = apiAdapter;
      final rawDio = Dio()..httpClientAdapter = putAdapter;

      final repo = CheckInRepository(dio: apiDio, rawDio: rawDio);
      final file = await _tempJpeg(List.filled(1024, 0));

      await expectLater(
        repo.uploadPhotoAndAttach(
          checkInId: 'chk-1',
          file: file,
          onProgress: (_) {},
        ),
        throwsA(isA<StorageDisabledException>()),
      );
      expect(apiAdapter.presignCalls, 1);
      expect(putAdapter.calls, 0,
          reason: 'PUT must not run after a STORAGE_DISABLED presign');
      expect(apiAdapter.attachCalls, 0,
          reason: 'attach must not run after a STORAGE_DISABLED presign');
    });

    test('PUT 500 throws generic upload exception and skips attach', () async {
      final apiAdapter = _ApiAdapter();
      final putAdapter = _PutAdapter(status: 500);

      final apiDio = Dio(BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ))
        ..httpClientAdapter = apiAdapter;
      final rawDio = Dio()..httpClientAdapter = putAdapter;

      final repo = CheckInRepository(dio: apiDio, rawDio: rawDio);
      final file = await _tempJpeg(List.filled(1024, 0));

      await expectLater(
        repo.uploadPhotoAndAttach(
          checkInId: 'chk-1',
          file: file,
          onProgress: (_) {},
        ),
        throwsA(
          allOf(
            isA<PhotoUploadException>(),
            isNot(isA<StorageDisabledException>()),
          ),
        ),
      );
      expect(apiAdapter.presignCalls, 1);
      expect(putAdapter.calls, 1);
      expect(apiAdapter.attachCalls, 0,
          reason: 'attach must not run when the PUT failed');
    });
  });
}
