// KAMOS — Dio interceptor: attach JWT, normalise errors, react to 401.
//
// SPEC §6.9: JWT is read from `flutter_secure_storage` only.
// On 401 from any non-auth endpoint, clear the token. Routing reacts to the
// auth state change via Riverpod and bounces to `/auth`.

import 'package:dio/dio.dart';

import 'api_exception.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.onAuthExpired,
  });

  final SecureStorageService storage;

  /// Called once when a non-auth request returns 401. Clears stored token and
  /// notifies the auth controller to switch state.
  final void Function() onAuthExpired;

  static const _authPaths = {
    '/v1/auth/login',
    '/v1/auth/register',
    '/v1/auth/google',
    '/v1/auth/verify-email',
    '/v1/auth/resend-verification',
  };

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
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode ?? 0;
    final path = err.requestOptions.path;
    final isAuthCall = _authPaths.any(path.startsWith);

    if (status == 401 && !isAuthCall) {
      // Fire-and-forget; the token clear is best-effort and the router can
      // react on the next provider read.
      storage.clearToken().then((_) => onAuthExpired());
    }

    // Translate any Dio failure into an ApiException so downstream layers
    // never need to import Dio.
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

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: wrapped,
        message: message,
      ),
    );
  }
}
