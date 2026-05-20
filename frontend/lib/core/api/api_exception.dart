// KAMOS — API error type.
//
// Matches the backend response shape `{ error, code }` (see openapi.yaml
// `components/schemas/Error`). Constructed by `ApiClient` from Dio errors so
// repositories and notifiers can match on `code` rather than HTTP status when
// the surface needs to distinguish (e.g. `EMAIL_TAKEN` vs generic 409).

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  /// HTTP status code; `0` when the request never reached the server.
  final int statusCode;

  /// Machine code in UPPER_SNAKE_CASE; empty when no body was decoded.
  final String code;

  /// Human-readable message, in the locale the server chose to emit.
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
