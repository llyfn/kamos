// KAMOS — AuthController. Drives login, register, Google handoff. On success
// the JWT pair is persisted by the repository and authStateProvider is flipped.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../repository/auth_repository.dart';
import 'auth_state.dart';

class AuthControllerState {
  const AuthControllerState({this.isSubmitting = false, this.error});
  final bool isSubmitting;
  final String? error;

  AuthControllerState copyWith({bool? isSubmitting, String? error}) =>
      AuthControllerState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
      );
}

class AuthControllerNotifier extends Notifier<AuthControllerState> {
  @override
  AuthControllerState build() => const AuthControllerState();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthControllerState(isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      ref.read(authStateProvider.notifier).signIn();
      state = const AuthControllerState();
    } on DioException catch (e) {
      state = AuthControllerState(error: _readError(e));
    } catch (e) {
      state = AuthControllerState(error: e.toString());
    }
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    String? displayName,
    String locale = 'en',
  }) async {
    state = const AuthControllerState(isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
            displayName: displayName,
            locale: locale,
          );
      ref.read(authStateProvider.notifier).signIn();
      state = const AuthControllerState();
    } on DioException catch (e) {
      state = AuthControllerState(error: _readError(e));
    } catch (e) {
      state = AuthControllerState(error: e.toString());
    }
  }

  /// Exchange a Google ID token (already obtained via the platform SDK) for a
  /// KAMOS session. The Flutter app never sees the Google client secret —
  /// the server is the only party that calls Google's verifier.
  Future<void> signInWithGoogle({
    required String idToken,
    String locale = 'en',
  }) async {
    state = const AuthControllerState(isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).google(
            idToken: idToken,
            locale: locale,
          );
      ref.read(authStateProvider.notifier).signIn();
      state = const AuthControllerState();
    } on DioException catch (e) {
      state = AuthControllerState(error: _readError(e));
    } catch (e) {
      state = AuthControllerState(error: e.toString());
    }
  }

  String _readError(DioException e) {
    final err = e.error;
    if (err is ApiException) return err.message;
    return e.message ?? 'Request failed';
  }
}

final authControllerProvider =
    NotifierProvider<AuthControllerNotifier, AuthControllerState>(
  AuthControllerNotifier.new,
);
