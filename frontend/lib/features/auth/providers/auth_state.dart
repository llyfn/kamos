// KAMOS — Auth state provider.
//
// Holds the boolean "is user signed in". Read on app start to decide between
// `/auth` and `/`. The token pair (access + refresh) lives in
// `flutter_secure_storage`; this notifier reads them only at bootstrap and
// on logout.
//
// SPEC §6.9: the JWTs live in `flutter_secure_storage`. This notifier never
// stores the tokens in memory beyond the bootstrap moment.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../repository/auth_repository.dart';

class AuthState {
  const AuthState({required this.isAuthenticated, this.isLoading = false});
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
    final storage = ref.read(secureStorageProvider);
    final access = await storage.readToken();
    // Either token by itself counts as "signed in" — the interceptor will
    // refresh the access token automatically the next time the app touches a
    // protected endpoint. Holding only an expired access token is fine too;
    // the same 401 → refresh path handles it.
    final refresh = await storage.readRefreshToken();
    final hasToken =
        (access != null && access.isNotEmpty) ||
        (refresh != null && refresh.isNotEmpty);
    state = AuthState(isAuthenticated: hasToken, isLoading: false);
  }

  /// Called by the repository after a successful login/register. The tokens
  /// are already written to secure storage; we only flip the flag here.
  void signIn() {
    state = const AuthState(isAuthenticated: true, isLoading: false);
  }

  /// Full sign-out. Best-effort calls `POST /v1/auth/logout` so the server can
  /// revoke the refresh token, then wipes both tokens from secure storage.
  /// Server failures are swallowed (handled inside `AuthRepository.logout`)
  /// so logout is never blocked by a network outage.
  ///
  /// `dioProvider` is invalidated after the tokens are cleared so the
  /// in-memory `MemCacheStore` held in its closure is destroyed along with
  /// the singleton. The next provider read rebuilds a fresh Dio + fresh
  /// cache; the previous user's cached responses are unreachable even if
  /// the next user goes offline before their first authed fetch.
  ///
  /// `meProvider` + `feedProvider` are also invalidated. Both are long-lived
  /// (NotifierProvider / FutureProvider, not `autoDispose`), so without an
  /// explicit invalidation the next signed-in user would see the previous
  /// user's profile + feed until something else triggered a refetch. The
  /// `family`-keyed providers (userCheckinsProvider, public profile…) are
  /// `autoDispose` and drop their cache on navigation, so they don't need
  /// explicit handling here.
  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    final refresh = await storage.readRefreshToken();
    await ref.read(authRepositoryProvider).logout(refreshToken: refresh);
    await storage.clearAll();
    ref.invalidate(dioProvider);
    ref.invalidate(meProvider);
    ref.invalidate(feedProvider);
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  /// Called by the Dio interceptor when refresh exchange has failed. Tokens
  /// have already been cleared by the interceptor at this point. Invalidating
  /// `dioProvider` + the session-scoped data providers closes the cross-user
  /// offline-read hole described on [logout]: a hard 401 wipes the cache the
  /// same way a clean logout does.
  void onUnauthorized() {
    if (state.isAuthenticated) {
      ref.invalidate(dioProvider);
      ref.invalidate(meProvider);
      ref.invalidate(feedProvider);
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
