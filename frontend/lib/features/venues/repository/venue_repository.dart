// KAMOS — VenueRepository.
//
// Wraps `GET /v1/venues/search`. The endpoint is a thin proxy to Foursquare
// Places; the backend may answer 503 with one of two `code`s the UI must
// distinguish:
//
//   * `VENUE_SEARCH_DISABLED` — server has no FOURSQUARE_API_KEY. The UI
//     should suggest checking in without a venue.
//   * `VENUE_RATE_LIMITED`    — upstream 429 from Foursquare. The UI should
//     ask the user to retry shortly.
//
// Check-in venue attachment does NOT live in this repository — it goes
// through `CheckInRepository.create` as the `venue` field on the POST body.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/venue.dart';
import '../../../core/observability/sentry_observer.dart';
import '../../../core/api/api_exceptions.dart';

/// Wraps the `venues` tag of [KamosApi] (Foursquare-backed venue
/// search) and lifts `DioException` into [VenueSearchDisabledException] /
/// [VenueRateLimitedException] in `core/api/api_exceptions.dart`. Used by
/// the venues feature's picker sheet inside the check-in flow.
class VenueRepository {
  VenueRepository(Dio dio) : _api = KamosApi(dio);
  final KamosApi _api;

  /// Calls `GET /v1/venues/search?q=&lat=&lng=&locale=`. Returns the
  /// `items` array as `FoursquarePlace`s. The endpoint is NOT
  /// cursor-paginated (per OpenAPI).
  Future<List<FoursquarePlace>> search({
    required String query,
    double? lat,
    double? lng,
    String locale = 'en',
  }) async {
    try {
      final data = await _api.venues.search(
        query: query,
        lat: lat,
        lng: lng,
        locale: locale,
      );
      if (data.isEmpty) {
        // 200 with an unexpected body shape — should never happen, but a
        // server bug or upstream proxy mangling the response would land here.
        // Don't swallow silently; route to Sentry so we can see it. The user
        // still gets an empty result rather than a hard error.
        if (kSentryConfigured) {
          Sentry.captureMessage(
            'venues/search: unexpected response shape',
            level: SentryLevel.warning,
            withScope: (scope) {
              scope.setContexts('response', {'runtimeType': 'empty'});
            },
          );
        } else {
          debugPrint('venues/search: unexpected response shape (empty)');
        }
        return const [];
      }
      final items = (data['items'] as List?) ?? const [];
      return items
          .map((e) => FoursquarePlace.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
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
      if (status == 503 && code == 'VENUE_SEARCH_DISABLED') {
        throw const VenueSearchDisabledException();
      }
      if (status == 503 && code == 'VENUE_RATE_LIMITED') {
        throw const VenueRateLimitedException();
      }
      rethrow;
    }
  }
}

final venueRepositoryProvider = Provider<VenueRepository>(
  (ref) => VenueRepository(ref.read(dioProvider)),
);
