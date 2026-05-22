// KAMOS — BeverageRequestRepository.submit tests (Phase 5 user-side).
//
// Drives `POST /v1/beverage-requests` through a custom Dio adapter.
// Verifies the request body shape and that non-2xx surfaces as
// `BeverageRequestSubmissionException`.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/api_exceptions.dart';
import 'package:kamos/core/models/beverage_request.dart';
import 'package:kamos/features/beverage_requests/repository/beverage_request_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.status, required this.body});

  final int status;
  final Map<String, dynamic> body;

  RequestOptions? lastRequest;
  String? lastBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final raw = options.data;
    lastBody = raw is String ? raw : jsonEncode(raw);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Dio _dio(_Adapter adapter) {
  return Dio(BaseOptions(
    baseUrl: 'https://api.test',
    validateStatus: (s) => s != null && s >= 200 && s < 300,
    headers: {'Content-Type': 'application/json'},
  ))
    ..httpClientAdapter = adapter;
}

void main() {
  group('BeverageRequestRepository.submit', () {
    test('202 succeeds and POSTs the payload-wrapped body to the right path',
        () async {
      final adapter = _Adapter(
        status: 202,
        body: const {'id': 'req-1'},
      );
      final repo = BeverageRequestRepository(_dio(adapter));

      await repo.submit(const BeverageRequest(
        name: 'Dassai 45',
        breweryName: 'Asahi Shuzo',
        categorySlug: 'nihonshu',
        notes: 'Junmai Daiginjo',
      ));

      final req = adapter.lastRequest!;
      expect(req.path, '/v1/beverage-requests');
      expect(req.method, 'POST');

      final decoded = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
      expect(decoded['payload'], isA<Map<String, dynamic>>());
      final payload = decoded['payload'] as Map<String, dynamic>;
      expect(payload['name'], 'Dassai 45');
      expect(payload['brewery_name'], 'Asahi Shuzo');
      expect(payload['category_slug'], 'nihonshu');
      expect(payload['notes'], 'Junmai Daiginjo');
    });

    test('422 surfaces BeverageRequestSubmissionException', () async {
      final adapter = _Adapter(
        status: 422,
        body: const {'error': 'payload is required', 'code': 'VALIDATION'},
      );
      final repo = BeverageRequestRepository(_dio(adapter));

      await expectLater(
        repo.submit(const BeverageRequest(
          name: 'X',
          breweryName: 'Y',
          categorySlug: 'shochu',
        )),
        throwsA(isA<BeverageRequestSubmissionException>()),
      );
    });

    test('500 surfaces BeverageRequestSubmissionException', () async {
      final adapter = _Adapter(
        status: 500,
        body: const {'error': 'boom', 'code': 'INTERNAL'},
      );
      final repo = BeverageRequestRepository(_dio(adapter));

      await expectLater(
        repo.submit(const BeverageRequest(
          name: 'X',
          breweryName: 'Y',
          categorySlug: 'liqueur',
        )),
        throwsA(isA<BeverageRequestSubmissionException>()),
      );
    });
  });
}
