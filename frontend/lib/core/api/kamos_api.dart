// KAMOS — Typed HTTP facade.
//
// Single source of truth for every backend path and HTTP verb the Flutter
// client speaks. Repositories delegate through this facade rather than
// embedding `/v1/...` strings; openapi.yaml is the contract behind it.
//
// Why hand-written, not codegen
// -----------------------------
// We evaluated `openapi_generator` (v6.1.0, latest stable on pub.dev) but
// its dependency graph pins `analyzer >=2.0.0 <7.0.0`, which conflicts with
// the project's existing `build_runner 2.15.0` (resolves `analyzer 10.0.1`).
// `flutter pub get` would have to downgrade the entire codegen toolchain.
// That trade — risking a broken generator output for the convenience of
// not maintaining this file — was not worth it for a 13-repository surface
// of cursor-paged GETs, idempotent POSTs, and small PATCH bodies.
//
// Strategy
// --------
// * One typed method per OpenAPI operationId, grouped under sub-facades by
//   the operation's tag (`facade.auth.login(...)`, `facade.feed.getFeed(...)`).
// * Methods return raw `Map<String, dynamic>` / `List<dynamic>` payloads. The
//   per-feature `Repository` adapts the payload to the existing freezed
//   domain models via their `fromJson` factories — keeping the existing
//   wire-shape boundary stable and avoiding a churn of generated DTOs that
//   would shadow them.
// * Errors are *not* swallowed here — `AuthInterceptor` already normalises
//   `DioException` and `KamosApiException.fromDio` (see `api_exceptions.dart`)
//   turns the interceptor's wrapped error into a typed exception at the
//   repository layer.
// * `forceRefresh` is preserved via the `kBypassCache` extras (see the feed
//   facade) — `dio_cache_interceptor` honours the per-request override.
//
// The `Dio` passed in is the authed singleton from `dioProvider`, so every
// call here flows through `AuthInterceptor` + `DioCacheInterceptor` + Sentry's
// breadcrumb interceptor without any extra wiring.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'cache_extras.dart';

/// Path constants — every backend route the Flutter app talks to. Centralised
/// here so a backend rename is a one-line change. Parameterised paths use a
/// `String Function(...)` so the call site stays type-checked.
class ApiPaths {
  ApiPaths._();

  // auth
  static const authRegister = '/v1/auth/register';
  static const authLogin = '/v1/auth/login';
  static const authGoogle = '/v1/auth/google';
  static const authRefresh = '/v1/auth/refresh';
  static const authLogout = '/v1/auth/logout';
  static const authVerifyEmail = '/v1/auth/verify-email';
  static const authResendVerification = '/v1/auth/resend-verification';
  static const authPasswordChange = '/v1/auth/password-change';
  static const authEmailChange = '/v1/auth/email-change';

  // users
  static const usersMe = '/v1/users/me';
  static const usersSearch = '/v1/users/search';
  static String user(String username) => '/v1/users/$username';
  static String userCheckins(String username) =>
      '/v1/users/$username/check-ins';
  static String userCollections(String username) =>
      '/v1/users/$username/collections';
  static String userBeverages(String username) =>
      '/v1/users/$username/beverages';
  static String userFollowers(String username) =>
      '/v1/users/$username/followers';
  static String userFollowing(String username) =>
      '/v1/users/$username/following';

  // beverages
  static const beverages = '/v1/beverages';
  static String beverage(String id) => '/v1/beverages/$id';

  // producers
  static String producer(String id) => '/v1/producers/$id';

  // check-ins
  static const checkins = '/v1/check-ins';
  static String checkin(String id) => '/v1/check-ins/$id';
  static String checkinPhotos(String checkInId) =>
      '/v1/check-ins/$checkInId/photos';
  static String checkinToast(String checkInId) =>
      '/v1/check-ins/$checkInId/toast';
  static String checkinComments(String checkInId) =>
      '/v1/check-ins/$checkInId/comments';
  static const uploadsPhotoPresign = '/v1/uploads/photo-presign';

  // comments
  static String comment(String id) => '/v1/comments/$id';

  // collections
  static const collections = '/v1/collections';
  static String collection(String id) => '/v1/collections/$id';
  static String collectionEntries(String collectionId) =>
      '/v1/collections/$collectionId/entries';
  static String collectionEntry(String collectionId, String beverageId) =>
      '/v1/collections/$collectionId/entries/$beverageId';

  // feed
  static const feed = '/v1/feed';

  // social
  static String userFollow(String username) => '/v1/users/$username/follow';
  // Note: GET /v1/follow-requests is removed by the backend alongside the
  // standalone Inbox screen (ARCH-005). The approve / decline endpoints
  // stay — _FollowRequestActions in the notification row still calls them.
  static String followRequestApprove(String userId) =>
      '/v1/follow-requests/$userId/approve';
  static String followRequestDecline(String userId) =>
      '/v1/follow-requests/$userId/decline';

  // notifications
  static const notifications = '/v1/notifications';
  static const notificationsRead = '/v1/notifications/read';
  static const notificationsUnreadCount = '/v1/notifications/unread-count';

  // search + taxonomy
  static const search = '/v1/search';
  static const categories = '/v1/categories';
  static const flavorTags = '/v1/flavor-tags';

  // venues + beverage-requests
  static const venuesSearch = '/v1/venues/search';
  static const beverageRequests = '/v1/beverage-requests';
}

/// Typed HTTP facade over the authed Dio singleton. Construct via
/// [kamosApiProvider]; tests can construct directly with a stubbed `Dio` to
/// drive the same code path repositories use.
class KamosApi {
  KamosApi(this._dio)
    : auth = KamosAuthApi(_dio),
      users = KamosUsersApi(_dio),
      beverages = KamosBeveragesApi(_dio),
      producers = KamosProducersApi(_dio),
      checkins = KamosCheckinsApi(_dio),
      comments = KamosCommentsApi(_dio),
      collections = KamosCollectionsApi(_dio),
      feed = KamosFeedApi(_dio),
      social = KamosSocialApi(_dio),
      search = KamosSearchApi(_dio),
      taxonomy = KamosTaxonomyApi(_dio),
      venues = KamosVenuesApi(_dio),
      uploads = KamosUploadsApi(_dio),
      beverageRequests = KamosBeverageRequestsApi(_dio),
      notifications = KamosNotificationsApi(_dio);

  // ignore: unused_field — held for symmetry; sub-APIs capture it directly.
  final Dio _dio;

  final KamosAuthApi auth;
  final KamosUsersApi users;
  final KamosBeveragesApi beverages;
  final KamosProducersApi producers;
  final KamosCheckinsApi checkins;
  final KamosCommentsApi comments;
  final KamosCollectionsApi collections;
  final KamosFeedApi feed;
  final KamosSocialApi social;
  final KamosSearchApi search;
  final KamosTaxonomyApi taxonomy;
  final KamosVenuesApi venues;
  final KamosUploadsApi uploads;
  final KamosBeverageRequestsApi beverageRequests;
  final KamosNotificationsApi notifications;
}

// ---------------------------------------------------------------------------
// Internal helpers.

Map<String, dynamic> _asMap(Object? data) =>
    data is Map<String, dynamic> ? data : <String, dynamic>{};

List<dynamic> _asList(Object? data) => data is List ? data : const <dynamic>[];

/// Strips null-valued entries so the encoded JSON body never includes
/// `key: null` (the backend's PATCH handlers treat present-null as "clear"
/// for some fields). Repositories that want explicit null can build the
/// map themselves and pass through `data` parameter unchanged.
Map<String, dynamic> _compact(Map<String, dynamic> m) {
  m.removeWhere((_, v) => v == null);
  return m;
}

// ---------------------------------------------------------------------------
// auth — POST endpoints. Returns the AuthResponse-shaped map for the caller.

class KamosAuthApi {
  KamosAuthApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.authLogin,
      data: {'email': email, 'password': password},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
    String locale = 'en',
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.authRegister,
      data: _compact({
        'username': username,
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        'locale': locale,
      }),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> google({
    required String idToken,
    String? username,
    String locale = 'en',
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.authGoogle,
      data: _compact({
        'id_token': idToken,
        if (username != null && username.isNotEmpty) 'username': username,
        'locale': locale,
      }),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.authRefresh,
      data: {'refresh_token': refreshToken},
    );
    return _asMap(res.data);
  }

  Future<void> logout({String? refreshToken}) async {
    await _dio.post<dynamic>(
      ApiPaths.authLogout,
      data: refreshToken != null && refreshToken.isNotEmpty
          ? {'refresh_token': refreshToken}
          : <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.authVerifyEmail,
      data: {'token': token},
    );
    return _asMap(res.data);
  }

  Future<void> resendVerification() async {
    await _dio.post<dynamic>(ApiPaths.authResendVerification);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post<dynamic>(
      ApiPaths.authPasswordChange,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<void> changeEmail(String newEmail) async {
    await _dio.post<dynamic>(
      ApiPaths.authEmailChange,
      data: {'new_email': newEmail},
    );
  }
}

// ---------------------------------------------------------------------------
// users

class KamosUsersApi {
  KamosUsersApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get<dynamic>(ApiPaths.usersMe);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> updateMe({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? locale,
    String? privacyMode,
  }) async {
    final res = await _dio.patch<dynamic>(
      ApiPaths.usersMe,
      data: _compact({
        'display_name': displayName,
        'bio': bio,
        'avatar_url': avatarUrl,
        'locale': locale,
        'privacy_mode': privacyMode,
      }),
    );
    return _asMap(res.data);
  }

  Future<void> deleteMe() async {
    await _dio.delete<dynamic>(ApiPaths.usersMe);
  }

  Future<Map<String, dynamic>> getUser(String username) async {
    final res = await _dio.get<dynamic>(ApiPaths.user(username));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> getUserCheckins(
    String username, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.userCheckins(username),
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }

  /// Case-insensitive user search. The server enforces a 2-char minimum on
  /// `q`; callers should mirror that so the user never sees a 400 toast.
  Future<Map<String, dynamic>> searchUsers({
    required String q,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.usersSearch,
      queryParameters: {
        'q': q,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }

  /// Visibility-gated page of the named user's collections. Owner-as-viewer
  /// sees all; every other viewer sees only public rows. 404 when the
  /// username does not resolve.
  Future<Map<String, dynamic>> getUserCollections(
    String username, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.userCollections(username),
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }

  /// Distinct-beverage aggregation for the named user. Filters
  /// (`category`, `producerId`, `minRating`) and sort axis are all
  /// optional. Cursor pagination, page size 20 (SPEC §6.6).
  Future<Map<String, dynamic>> getUserBeverages(
    String username, {
    String? cursor,
    String? category,
    String? producerId,
    double? minRating,
    String sort = 'rating',
    String? sortDir,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.userBeverages(username),
      queryParameters: _compact({
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (category != null && category.isNotEmpty) 'category': category,
        if (producerId != null && producerId.isNotEmpty) 'producer_id': producerId,
        'min_rating': ?minRating,
        'sort': sort,
        if (sortDir != null && sortDir.isNotEmpty) 'sort_dir': sortDir,
        'limit': limit,
      }),
    );
    return _asMap(res.data);
  }

  /// Cursor-paginated followers list. `q` is the optional case-insensitive
  /// prefix filter against `username` + `display_name`; empty / whitespace
  /// values are stripped before sending so the server never receives a
  /// no-op filter.
  Future<Map<String, dynamic>> getUserFollowers(
    String username, {
    String? cursor,
    String? q,
    int limit = 20,
  }) async {
    final trimmed = q?.trim();
    final res = await _dio.get<dynamic>(
      ApiPaths.userFollowers(username),
      queryParameters: _compact({
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (trimmed != null && trimmed.isNotEmpty) 'q': trimmed,
        'limit': limit,
      }),
    );
    return _asMap(res.data);
  }

  /// Cursor-paginated following list. See [getUserFollowers] for `q`
  /// semantics.
  Future<Map<String, dynamic>> getUserFollowing(
    String username, {
    String? cursor,
    String? q,
    int limit = 20,
  }) async {
    final trimmed = q?.trim();
    final res = await _dio.get<dynamic>(
      ApiPaths.userFollowing(username),
      queryParameters: _compact({
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (trimmed != null && trimmed.isNotEmpty) 'q': trimmed,
        'limit': limit,
      }),
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// beverages

class KamosBeveragesApi {
  KamosBeveragesApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> list({
    String? q,
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.beverages,
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (category != null && category.isNotEmpty) 'category': category,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> get(String id, {bool forceRefresh = false}) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.beverage(id),
      options: forceRefresh ? Options(extra: {...kBypassCache}) : null,
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// producers

class KamosProducersApi {
  KamosProducersApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> get(String id) async {
    final res = await _dio.get<dynamic>(ApiPaths.producer(id));
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// check-ins (post + toast + photo attach)

class KamosCheckinsApi {
  KamosCheckinsApi(this._dio);
  final Dio _dio;

  /// `null`-valued fields are stripped before the body is sent; `rating`
  /// is included only when non-null (the create endpoint treats absent
  /// rating as "no rating" which is distinct from `0.0`).
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _dio.post<dynamic>(ApiPaths.checkins, data: _compact({...body}));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final res = await _dio.get<dynamic>(ApiPaths.checkin(id));
    return _asMap(res.data);
  }

  /// Body forwarded verbatim — caller owns the tri-state contract
  /// (absent vs. explicit null) on rating / review / price (SPEC §4.4).
  /// Do NOT route through `_compact`: it would collapse explicit nulls.
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch<dynamic>(
      ApiPaths.checkin(id),
      data: body,
    );
    return _asMap(res.data);
  }

  Future<void> deleteOne(String id) async {
    await _dio.delete<dynamic>(ApiPaths.checkin(id));
  }

  Future<Map<String, dynamic>> attachPhoto({
    required String checkInId,
    required String uploadId,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.checkinPhotos(checkInId),
      data: {'upload_id': uploadId},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> toggleToast(String checkInId) async {
    final res = await _dio.post<dynamic>(ApiPaths.checkinToast(checkInId));
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// comments

class KamosCommentsApi {
  KamosCommentsApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> list(
    String checkInId, {
    String? cursor,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.checkinComments(checkInId),
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> create({
    required String checkInId,
    required String body,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.checkinComments(checkInId),
      data: {'body': body},
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> update({
    required String commentId,
    required String body,
  }) async {
    final res = await _dio.patch<dynamic>(
      ApiPaths.comment(commentId),
      data: {'body': body},
    );
    return _asMap(res.data);
  }

  Future<void> deleteOne(String commentId) async {
    await _dio.delete<dynamic>(ApiPaths.comment(commentId));
  }
}

// ---------------------------------------------------------------------------
// collections

class KamosCollectionsApi {
  KamosCollectionsApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> list() async {
    final res = await _dio.get<dynamic>(ApiPaths.collections);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> create(String name) async {
    final res = await _dio.post<dynamic>(ApiPaths.collections, data: {'name': name});
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> patch(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch<dynamic>(
      ApiPaths.collection(id),
      data: _compact({...body}),
    );
    return _asMap(res.data);
  }

  Future<void> delete(String id) async {
    await _dio.delete<dynamic>(ApiPaths.collection(id));
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final res = await _dio.get<dynamic>(ApiPaths.collection(id));
    return _asMap(res.data);
  }

  Future<void> addEntry(
    String collectionId,
    String beverageId, {
    String? note,
  }) async {
    await _dio.post<dynamic>(
      ApiPaths.collectionEntries(collectionId),
      data: _compact({
        'beverage_id': beverageId,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );
  }

  Future<void> removeEntry(String collectionId, String beverageId) async {
    await _dio.delete<dynamic>(ApiPaths.collectionEntry(collectionId, beverageId));
  }
}

// ---------------------------------------------------------------------------
// feed

class KamosFeedApi {
  KamosFeedApi(this._dio);
  final Dio _dio;

  /// Cursor pagination, page size 20 (SPEC §5.2). When `forceRefresh` is
  /// `true` the request is decorated with [kBypassCache] so the global
  /// `dio_cache_interceptor` skips the in-memory cache for this call —
  /// wired into the feed's pull-to-refresh gesture so a user-initiated
  /// refresh always round-trips to the origin.
  Future<Map<String, dynamic>> getFeed({
    String? cursor,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.feed,
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
      options: forceRefresh ? Options(extra: {...kBypassCache}) : null,
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// social (follow toggle + inbox)

class KamosSocialApi {
  KamosSocialApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> follow(String username) async {
    final res = await _dio.post<dynamic>(ApiPaths.userFollow(username));
    return _asMap(res.data);
  }

  Future<void> unfollow(String username) async {
    await _dio.delete<dynamic>(ApiPaths.userFollow(username));
  }

  Future<void> approveFollowRequest(String userId) async {
    await _dio.post<dynamic>(ApiPaths.followRequestApprove(userId));
  }

  Future<void> declineFollowRequest(String userId) async {
    await _dio.post<dynamic>(ApiPaths.followRequestDecline(userId));
  }
}

// ---------------------------------------------------------------------------
// search

class KamosSearchApi {
  KamosSearchApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> query({
    required String q,
    String? type,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.search,
      queryParameters: {
        'q': q,
        if (type != null && type.isNotEmpty) 'type': type,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// taxonomy (categories + flavor tags)

class KamosTaxonomyApi {
  KamosTaxonomyApi(this._dio);
  final Dio _dio;

  Future<List<dynamic>> categories() async {
    final res = await _dio.get<dynamic>(ApiPaths.categories);
    return _asList(res.data);
  }

  Future<List<dynamic>> flavorTags() async {
    final res = await _dio.get<dynamic>(ApiPaths.flavorTags);
    return _asList(res.data);
  }
}

// ---------------------------------------------------------------------------
// venues

class KamosVenuesApi {
  KamosVenuesApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> search({
    required String query,
    double? lat,
    double? lng,
    String locale = 'en',
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.venuesSearch,
      queryParameters: _compact({
        'q': query,
        'lat': lat,
        'lng': lng,
        'locale': locale,
      }),
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// uploads (presign)

class KamosUploadsApi {
  KamosUploadsApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> presignPhotoUpload({
    required String contentType,
    required int byteSize,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiPaths.uploadsPhotoPresign,
      data: {'content_type': contentType, 'byte_size': byteSize},
    );
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// beverage-requests

class KamosBeverageRequestsApi {
  KamosBeverageRequestsApi(this._dio);
  final Dio _dio;

  Future<void> submit(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>(ApiPaths.beverageRequests, data: payload);
  }
}

// ---------------------------------------------------------------------------
// notifications (SPEC §5.4 — in-app inbox + mark read + unread count)

class KamosNotificationsApi {
  KamosNotificationsApi(this._dio);
  final Dio _dio;

  /// Cursor pagination, page size 20 (SPEC §5.4). Returns the
  /// `PageOfNotification` envelope `{ items, next_cursor, has_more }`.
  Future<Map<String, dynamic>> list({
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiPaths.notifications,
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _asMap(res.data);
  }

  /// `POST /v1/notifications/read`. Exactly one of [ids] or [all] must be
  /// supplied — the server returns 422 if neither or both are sent. The
  /// response carries the rowcount of actually-transitioned rows so the
  /// caller can decide whether to invalidate further state.
  Future<Map<String, dynamic>> markRead({
    List<String>? ids,
    bool? all,
  }) async {
    final body = all == true
        ? <String, dynamic>{'all': true}
        : <String, dynamic>{'ids': ids ?? const <String>[]};
    final res = await _dio.post<dynamic>(
      ApiPaths.notificationsRead,
      data: body,
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> unreadCount() async {
    final res = await _dio.get<dynamic>(ApiPaths.notificationsUnreadCount);
    return _asMap(res.data);
  }
}

// ---------------------------------------------------------------------------
// Riverpod wiring.

/// Riverpod provider for [KamosApi]. Constructed lazily from the authed
/// `dioProvider` so the facade inherits the full interceptor stack
/// (`AuthInterceptor` + `DioCacheInterceptor` + Sentry).
final kamosApiProvider = Provider<KamosApi>(
  (ref) => KamosApi(ref.watch(dioProvider)),
);
