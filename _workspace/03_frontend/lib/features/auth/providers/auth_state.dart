// KAMOS — Auth state provider.
//
// Holds the boolean "is user signed in" plus the currently cached
// JWT-derived user. Read on app start to decide between `/auth` and `/`.
//
// SPEC §6.9: the JWT lives in `flutter_secure_storage`. This notifier never
// stores the token in memory beyond the bootstrap moment.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.isLoading = false,
  });
  final bool isAuthenticated;
  final bool isLoading;

  static const initial = AuthState(isAuthenticated: false, isLoading: true);

  AuthState copyWith({bool? isAuthenticated, bool? isLoading}) => AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Fire-and-forget bootstrap.
    Future.microtask(_load);
    return AuthState.initial;
  }

  Future<void> _load() async {
    final token = await ref.read(secureStorageProvider).readToken();
    state = AuthState(
      isAuthenticated: token != null && token.isNotEmpty,
      isLoading: false,
    );
  }

  /// Called by the repository after a successful login/register. The token
  /// is already written to secure storage; we only flip the flag here.
  void signIn() {
    state = const AuthState(isAuthenticated: true, isLoading: false);
  }

  Future<void> logout() async {
    await ref.read(secureStorageProvider).clearToken();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  /// Called by the Dio interceptor when a non-auth request returns 401.
  void onUnauthorized() {
    if (state.isAuthenticated) {
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }
}

final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);
