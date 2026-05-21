// KAMOS — Central API exceptions.
//
// Single source of truth for the typed exceptions that repositories throw.
// Previously each feature had its own `exceptions.dart`; the three legacy
// files (`features/comments/exceptions.dart`, `features/venues/exceptions.dart`,
// `features/beverage_requests/exceptions.dart`) now re-export from here so
// existing imports keep working while new code can pull everything from one
// place.
//
// Layers
// ------
// 1. **Base + HTTP-mapped exceptions** ([KamosApiException] and friends)
//    — generic shapes per HTTP status / Dio error category. Use
//    [mapDioException] to lift a raw `DioException` into one of these. The
//    `AuthInterceptor` (`api_client.dart`) already runs `_normalise` to wrap
//    each Dio error in an `ApiException` carrying `(statusCode, code,
//    message)`; this layer maps from there to the typed family.
//
// 2. **Feature-specific exceptions** (comments / venues / beverage-requests
//    / photo-upload) — for cases where the UI must distinguish a specific
//    response *code* (e.g. `STORAGE_DISABLED`, `VENUE_RATE_LIMITED`,
//    `COMMENT_DELETED`) and show a dedicated copy. These extend
//    [KamosApiException] so a callsite that wants to render a generic
//    fallback can still pattern-match on the base type.
//
// The base type implements `Exception`. Callers should never depend on
// `package:dio/dio.dart` for typed error handling — the repository layer
// converts before exposing to providers and widgets.

import 'package:dio/dio.dart';

import 'api_exception.dart';

// ---------------------------------------------------------------------------
// Base + HTTP-mapped family.

/// Base type for every typed API exception. Holds the HTTP status (or 0 for
/// transport-level failures), the machine `code` from the `Error` body (empty
/// when the body could not be decoded), and a human-readable message in the
/// locale the server chose to emit.
abstract class KamosApiException implements Exception {
  const KamosApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => '$runtimeType($statusCode $code: $message)';
}

/// 400/422 — request body or query failed schema/business validation. `code`
/// often carries a machine-readable hint (e.g. `INVALID_BEVERAGE_ID`).
class ValidationException extends KamosApiException {
  const ValidationException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 401 — missing or invalid bearer. The auth interceptor already runs the
/// refresh-token dance for a 401 on non-auth endpoints; this exception
/// surfaces when the refresh itself failed (or the call was an /auth/* one).
class UnauthorizedException extends KamosApiException {
  const UnauthorizedException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 403 — the request was authenticated but disallowed for this principal
/// (e.g. deleting someone else's comment, viewing a private collection).
class ForbiddenException extends KamosApiException {
  const ForbiddenException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 404 — the resource does not exist (or was soft-deleted and is now hidden).
class NotFoundException extends KamosApiException {
  const NotFoundException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 409 — write conflict (e.g. duplicate username, already-toasted check-in).
class ConflictException extends KamosApiException {
  const ConflictException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 429 — global or per-endpoint rate-limit. Some endpoints emit a specific
/// subclass below (e.g. [CommentRateLimitedException]).
class RateLimitedException extends KamosApiException {
  const RateLimitedException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// 5xx — server-side failure. The `message` is best-effort; the body may
/// be opaque.
class ServerException extends KamosApiException {
  const ServerException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}

/// statusCode == 0 — request never reached the server (connect/send/receive
/// timeout, socket error). `AuthInterceptor` already fires the network toast
/// in this case; repositories may still throw this so callers can short-circuit
/// retry UIs without consulting the toast bus.
class NetworkException extends KamosApiException {
  const NetworkException({super.code = '', super.message = 'network error'})
    : super(statusCode: 0);
}

// ---------------------------------------------------------------------------
// Dio → KamosApiException mapping.

/// Lifts a raw [DioException] into the typed family. The `AuthInterceptor`
/// (`api_client.dart`) wraps every Dio error's `error` field in an
/// [ApiException]; this helper reads that wrapper when available and falls
/// back to the raw status code and body otherwise.
///
/// `bodyCode` and `bodyMessage` come from the standard KAMOS error envelope
/// `{ "error": "<human>", "code": "<MACHINE>" }` — see `openapi.yaml`
/// `components/schemas/Error`.
KamosApiException mapDioException(DioException err) {
  final wrapped = err.error;
  int status = err.response?.statusCode ?? 0;
  String code = '';
  String message = err.message ?? 'request failed';

  // Prefer the interceptor's normalised wrapper when present.
  if (wrapped is ApiException) {
    status = wrapped.statusCode;
    code = wrapped.code;
    message = wrapped.message;
  } else {
    final body = err.response?.data;
    if (body is Map<String, dynamic>) {
      code = (body['code'] as String?) ?? '';
      message = (body['error'] as String?) ?? message;
    }
  }

  // Transport-level: never reached the server.
  if (status == 0) {
    return NetworkException(code: code, message: message);
  }

  if (status == 401) {
    return UnauthorizedException(
      statusCode: status,
      code: code,
      message: message,
    );
  }
  if (status == 403) {
    return ForbiddenException(
      statusCode: status,
      code: code,
      message: message,
    );
  }
  if (status == 404) {
    return NotFoundException(statusCode: status, code: code, message: message);
  }
  if (status == 409) {
    return ConflictException(statusCode: status, code: code, message: message);
  }
  if (status == 429) {
    return RateLimitedException(
      statusCode: status,
      code: code,
      message: message,
    );
  }
  if (status == 400 || status == 422) {
    return ValidationException(
      statusCode: status,
      code: code,
      message: message,
    );
  }
  if (status >= 500) {
    return ServerException(statusCode: status, code: code, message: message);
  }
  // Fallback: anything 4xx not explicitly handled becomes a generic validation.
  return ValidationException(
    statusCode: status,
    code: code,
    message: message,
  );
}

// ---------------------------------------------------------------------------
// Feature-specific exceptions.
//
// These cover the cases where the UI must render a dedicated message keyed
// on a specific server `code` rather than the generic "request failed" toast.
// All inherit [KamosApiException] so a generic catch (`on KamosApiException`)
// still works for the broader fallback path.

// ----- comments -----

/// 403 on `DELETE /v1/comments/{id}` — viewer is not the comment author.
class CommentForbiddenException extends ForbiddenException {
  const CommentForbiddenException()
    : super(
        statusCode: 403,
        code: '',
        message: 'Cannot delete this comment (not the author).',
      );
}

/// 404 (or 410 with `COMMENT_DELETED`) — the comment is already gone.
class CommentDeletedException extends NotFoundException {
  const CommentDeletedException()
    : super(
        statusCode: 404,
        code: 'COMMENT_DELETED',
        message: 'This comment has already been deleted.',
      );
}

/// Local-side enforcement of the 500-char cap so the UI shows a dedicated
/// message before the request goes out. Mirrors the server check.
class CommentTooLongException extends ValidationException {
  const CommentTooLongException()
    : super(
        statusCode: 422,
        code: 'COMMENT_TOO_LONG',
        message: 'Comment exceeds the 500-character limit.',
      );
}

/// Local-side rejection of C0 control bytes outside `\t` / `\n` (and DEL).
/// Mirrors the server-side filter so the UI can show a dedicated message
/// rather than the generic failure toast.
class CommentInvalidBodyException extends ValidationException {
  const CommentInvalidBodyException()
    : super(
        statusCode: 422,
        code: 'COMMENT_INVALID_BODY',
        message: 'Comment contains invalid characters.',
      );
}

/// 429 on `POST /v1/check-ins/{id}/comments` — the per-user throttle (3 rps
/// / burst 6) tripped. Dedicated copy keeps the user from re-tapping.
class CommentRateLimitedException extends RateLimitedException {
  const CommentRateLimitedException()
    : super(
        statusCode: 429,
        code: '',
        message: 'Commenting too fast — try again in a moment.',
      );
}

// ----- venues -----

/// 503 + `VENUE_SEARCH_DISABLED` on `GET /v1/venues/search` — server has no
/// `FOURSQUARE_API_KEY`. UI suggests checking in without a venue.
class VenueSearchDisabledException extends ServerException {
  const VenueSearchDisabledException()
    : super(
        statusCode: 503,
        code: 'VENUE_SEARCH_DISABLED',
        message: 'Venue search is not configured on this server.',
      );
}

/// 503 + `VENUE_RATE_LIMITED` — upstream Foursquare 429. UI asks user to
/// retry shortly.
class VenueRateLimitedException extends ServerException {
  const VenueRateLimitedException()
    : super(
        statusCode: 503,
        code: 'VENUE_RATE_LIMITED',
        message: 'Venue search rate-limited. Try again shortly.',
      );
}

// ----- beverage requests -----

/// Catch-all for `POST /v1/beverage-requests` failures. The endpoint has no
/// fine-grained surface (server validation is minimal), so the UI renders a
/// single generic message regardless of which transport-layer failure caused it.
class BeverageRequestSubmissionException extends KamosApiException {
  const BeverageRequestSubmissionException([this.cause])
    : super(
        statusCode: 0,
        code: '',
        message: 'beverage request submission failed',
      );

  /// The underlying transport failure (typically a `DioException` or one of
  /// the typed family above). `null` on purely local errors.
  final Object? cause;

  @override
  String toString() => 'BeverageRequestSubmissionException(${cause ?? ''})';
}

// ----- photo upload (used by CheckInRepository) -----

/// 503 + `STORAGE_DISABLED` on `POST /v1/uploads/photo-presign` — server has
/// no R2 configured. UI shows a "saved without photos" friendly path.
class StorageDisabledException extends ServerException {
  const StorageDisabledException([String? message])
    : super(
        statusCode: 503,
        code: 'STORAGE_DISABLED',
        message: message ?? 'Photo upload disabled',
      );
}

/// Any other failure in the 3-step photo upload chain (presign non-503,
/// PUT non-2xx, attach non-2xx, network errors). Carries an optional `stage`
/// (`presign` | `put` | `attach`) for telemetry.
class PhotoUploadException extends KamosApiException {
  const PhotoUploadException(String msg, {this.stage})
    : super(statusCode: 0, code: '', message: msg);

  final String? stage;

  @override
  String toString() => 'PhotoUploadException($stage): $message';
}
