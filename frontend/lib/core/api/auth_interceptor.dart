// KAMOS — Dio interceptor: attach JWT, normalise errors, react to 401.
//
// SPEC §6.9: JWT is read from `flutter_secure_storage` only.
//
// Refresh-token exchange loop: on a 401 from a non-auth endpoint, the
// interceptor pauses the original request, swaps the rotating refresh
// token for a fresh pair, and retries the original request once. If the
// refresh exchange itself fails (network or 4xx), both tokens are cleared
// and the unauthorized toast fires.
//
// Concurrency rule: at most one refresh exchange in flight at a time. Any
// concurrent 401s wait on the same Completer and retry when it resolves.
//
// Recursion rule: the refresh exchange is issued through a DIFFERENT `Dio`
// instance that does NOT carry this interceptor (see `api_client.dart`). The
// `/v1/auth/refresh` path is therefore never seen by `onError` here, which
// keeps the design free of self-reference.
//
// User-facing copy: the interceptor publishes an `ApiToastKind` on the
// `apiToastBusProvider` for the two transport-level cases that warrant a
// visible toast (`unauthorized`, `network`). The actual localized strings
// (`errorUnauthorized`, `errorNetwork`) are rendered by the app root listening
// to that bus — see `app.dart`.

import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_exception.dart';
import 'api_toast.dart';

/// Callback type for performing the refresh exchange. The interceptor does
/// not depend on `AuthRepository` directly — `api_client.dart` injects a
/// closure that uses a separate Dio so recursive 401s are impossible.
typedef RefreshExchange = Future<RefreshResult> Function(String refreshToken);

/// Outcome of one refresh exchange.
class RefreshResult {
  const RefreshResult.success(this.accessToken, this.refreshToken) : ok = true;
  const RefreshResult.failure()
    : ok = false,
      accessToken = '',
      refreshToken = '';

  final bool ok;
  final String accessToken;
  final String refreshToken;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshExchange,
    required this.onAuthExpired,
    required this.onApiToast,
  });

  /// Dio instance used to retry the original request after a successful
  /// refresh. Must be set by the owner (`api_client.dart`) immediately after
  /// constructing the interceptor; the late field lets us break the
  /// chicken-and-egg between `Dio.interceptors.add(interceptor)` and the need
  /// for the interceptor to know which Dio to retry through.
  late final Dio retryDio;

  final SecureStorageService storage;

  /// Performs the refresh exchange. Injected so the interceptor has no
  /// compile-time dependency on `AuthRepository`.
  final RefreshExchange refreshExchange;

  /// Called once when a refresh attempt fails. Tokens are already cleared by
  /// the time this fires; the host notifies the auth controller to switch
  /// state and route back to `/auth`.
  final void Function() onAuthExpired;

  /// Called when the interceptor wants to surface a localized toast. The host
  /// app translates the [ApiToastKind] into copy from `intl_*.arb` (i.e.
  /// `errorUnauthorized` / `errorNetwork`).
  final void Function(ApiToastKind kind) onApiToast;

  /// Auth-bearing endpoints whose 401 must NOT trigger a refresh attempt — the
  /// caller (login/register/etc.) handles the credential error directly. The
  /// `/refresh` path is included defensively even though the interceptor is
  /// not installed on the Dio that talks to it.
  static const _authPaths = {
    '/v1/auth/login',
    '/v1/auth/register',
    '/v1/auth/google',
    '/v1/auth/verify-email',
    '/v1/auth/resend-verification',
    '/v1/auth/refresh',
  };

  /// Single-flight guard. When non-null, a refresh is in progress; concurrent
  /// 401s `await` it and retry once it resolves with `true`.
  Completer<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode ?? 0;
    final path = err.requestOptions.path;
    final isAuthCall = _authPaths.any(path.startsWith);
    // Already retried once — do not loop.
    final alreadyRetried =
        err.requestOptions.extra['__kamos_retried__'] == true;

    if (status == 401 && !isAuthCall && !alreadyRetried) {
      final ok = await _tryRefresh();
      if (ok) {
        // Retry with the freshly-stored access token. The request goes through
        // the SAME Dio so this interceptor reattaches `Authorization` from
        // secure storage in `onRequest`.
        try {
          final retried = await _retry(err.requestOptions);
          handler.resolve(retried);
          return;
        } on DioException catch (retryErr) {
          // Fall through and normalise this as the new failure.
          err = retryErr;
        }
      } else {
        // Tokens already cleared in `_tryRefresh`; the host flips auth
        // state and AuthScreen renders the `wasExpired` fallback. No
        // toast — the fallback is the user-facing signal.
        onAuthExpired();
      }
    } else if (status == 0 &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.receiveTimeout)) {
      onApiToast(ApiToastKind.network);
    }

    handler.reject(_normalise(err));
  }

  /// Single-flight refresh. Returns true on success, false on failure (in
  /// which case tokens have been cleared as a side effect).
  Future<bool> _tryRefresh() async {
    // Coalesce concurrent 401s.
    final existing = _refreshInFlight;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;
    try {
      final refresh = await storage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await storage.clearAll();
        completer.complete(false);
        return false;
      }
      final result = await refreshExchange(refresh);
      if (!result.ok ||
          result.accessToken.isEmpty ||
          result.refreshToken.isEmpty) {
        await storage.clearAll();
        completer.complete(false);
        return false;
      }
      // `refreshExchange` (via AuthRepository.refresh) already persists the
      // new pair through `SecureStorageService` — no extra write here.
      completer.complete(true);
      return true;
    } catch (_) {
      await storage.clearAll();
      completer.complete(false);
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Retries the original request through the same Dio (so the same adapter,
  /// base URL, and timeouts are used). The stale `Authorization` header is
  /// stripped first so `onRequest` re-attaches the freshly-rotated access
  /// token from secure storage. The `__kamos_retried__` marker guards against
  /// a second 401 looping back into another refresh.
  Future<Response<dynamic>> _retry(RequestOptions o) {
    final headers = Map<String, dynamic>.from(o.headers)
      ..remove('Authorization');
    return retryDio.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: Options(
        method: o.method,
        headers: headers,
        contentType: o.contentType,
        responseType: o.responseType,
        followRedirects: o.followRedirects,
        validateStatus: o.validateStatus,
        extra: {...o.extra, '__kamos_retried__': true},
      ),
    );
  }

  /// Translate any Dio failure into an ApiException so downstream layers
  /// never need to import Dio.
  DioException _normalise(DioException err) {
    final status = err.response?.statusCode ?? 0;
    final body = err.response?.data;
    String code = '';
    String message = err.message ?? 'Request failed';
    if (body is Map<String, dynamic>) {
      code = (body['code'] as String?) ?? '';
      message = (body['error'] as String?) ?? message;
    }
    final wrapped = ApiException(
      statusCode: status,
      code: code,
      message: message,
    );
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: wrapped,
      message: message,
    );
  }
}
