// KAMOS — BeverageRequestRepository (user-side).
//
// Wraps `POST /v1/beverage-requests`. The endpoint expects a freeform
// `payload` object and returns `202 { id }` on success — the Flutter UI does
// not use the returned id today (admin review picks the row up by user), so
// `submit` returns void.
//
// Every non-2xx is normalised to `BeverageRequestSubmissionException`. The
// auth interceptor (api_client.dart) handles 401 + refresh by itself before
// the exception reaches us; we never see those as failure here.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/beverage_request.dart';

/// Wraps the `beverage-requests` tag of [KamosApi] (submit, queue
/// listing) and lifts `DioException` into the
/// [BeverageRequestSubmissionException] in `core/api/api_exceptions.dart`.
/// Used by the beverage-requests feature's submission screen.
class BeverageRequestRepository {
  BeverageRequestRepository(Dio dio) : _api = KamosApi(dio);
  final KamosApi _api;

  /// POST `/v1/beverage-requests` with the request body shaped by
  /// [BeverageRequest.toJson]. Throws [BeverageRequestSubmissionException]
  /// on any non-2xx response (server validation is minimal — only checks
  /// the payload is non-empty — so 422 here is unusual).
  Future<void> submit(BeverageRequest req) async {
    try {
      await _api.beverageRequests.submit(req.toJson());
    } on DioException catch (e) {
      throw BeverageRequestSubmissionException(e);
    }
  }
}

final beverageRequestRepositoryProvider = Provider<BeverageRequestRepository>(
  (ref) => BeverageRequestRepository(ref.watch(dioProvider)),
);
