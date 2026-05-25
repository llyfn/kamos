// KAMOS — Application router (go_router).
//
// Paths:
// /auth unauthenticated landing
// /auth/verify-pending post-signup "check your email" landing
// / feed (shell root)
// /search discover
// /check-in modal (needs a Beverage extra)
// /collections lists root
// /collections/:id detail
// /me self profile
// /me/edit edit profile
// /me/settings settings
// /inbox follow request inbox
// /users/search search for users by username/display name
// /users/:username other user
// /users/:username/lists other user's public collections
// /check-ins/:id check-in detail (— comments)
// /beverages/:id beverage detail
// /breweries/:id brewery detail
// /beverage-requests/new user-side "suggest a beverage" form
//
// Unauthenticated users are redirected to `/auth`; authenticated users on
// `/auth` are redirected to `/`. Verification is now end-to-end server-
// side: the mail link points at the backend's `/verify` HTML page, so
// the mobile app has no token-consuming screen — only a post-signup
// "check your mail" landing (`/auth/verify-pending`).
//
// Page transitions: every GoRoute uses `pageBuilder` returning
// `NoTransitionPage` — KAMOS pushes feel instant; the calm design language
// reads as a single surface morphing rather than a stack-slide.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/beverage.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/auth/screens/verify_email_pending_screen.dart';
import '../features/beverage_requests/screens/submit_beverage_request_screen.dart';
import '../features/beverages/screens/beverage_detail_screen.dart';
import '../features/breweries/screens/brewery_detail_screen.dart';
import '../features/check_in/screens/check_in_detail_screen.dart';
import '../features/check_in/screens/check_in_screen.dart';
import '../features/collections/screens/collection_detail_screen.dart';
import '../features/collections/screens/collections_list_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/social/screens/inbox_screen.dart';
import '../features/users/screens/other_user_collections_screen.dart';
import '../features/users/screens/user_search_screen.dart';
import '../shared/widgets/kamos_tab_bar.dart';

/// Wraps [child] in [NoTransitionPage]. Used by every [GoRoute.pageBuilder]
/// in this router so route pushes/replaces render without a slide / fade
/// animation. Centralised so individual routes don't repeat the key wiring.
NoTransitionPage<void> _noTransition(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final path = state.uri.path;
      final atAuth = path.startsWith('/auth');
      // The verify-pending screen renders right after signup, so the
      // user is already authenticated when they land there — keep
      // them on `/auth/verify-pending` rather than auto-redirecting
      // to `/` until they confirm verification (or skip).
      final isVerifyPending = path == '/auth/verify-pending';
      if (!auth.isAuthenticated && !atAuth) return '/auth';
      if (auth.isAuthenticated && atAuth && !isVerifyPending) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (_, state) => _noTransition(state, const AuthScreen()),
      ),
      GoRoute(
        path: '/auth/verify-pending',
        pageBuilder: (_, state) {
          final extra = state.extra;
          final email = extra is String
              ? extra
              : state.uri.queryParameters['email'] ?? '';
          return _noTransition(state, VerifyEmailPendingScreen(email: email));
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _noTransition(state, const FeedScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (_, state) =>
                _noTransition(state, const SearchScreen()),
          ),
          GoRoute(
            path: '/collections',
            pageBuilder: (_, state) =>
                _noTransition(state, const CollectionsListScreen()),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (_, state) =>
                _noTransition(state, const MeProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/check-in',
        pageBuilder: (_, state) {
          final b = state.extra as Beverage?;
          // Defensive: if launched without a beverage, bounce back to search.
          final child = b == null
              ? const SearchScreen()
              : CheckInScreen(beverage: b);
          return _noTransition(state, child);
        },
      ),
      GoRoute(
        path: '/collections/:id',
        pageBuilder: (_, state) => _noTransition(
          state,
          CollectionDetailScreen(collectionId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/me/edit',
        pageBuilder: (_, state) =>
            _noTransition(state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/me/settings',
        pageBuilder: (_, state) =>
            _noTransition(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/inbox',
        pageBuilder: (_, state) => _noTransition(state, const InboxScreen()),
      ),
      // Static-segment routes (`/users/search`, `/users/:username/lists`)
      // must precede `/users/:username` so go_router doesn't bind those
      // segments to the path parameter.
      GoRoute(
        path: '/users/search',
        pageBuilder: (_, state) =>
            _noTransition(state, const UserSearchScreen()),
      ),
      GoRoute(
        path: '/users/:username/lists',
        pageBuilder: (_, state) => _noTransition(
          state,
          OtherUserCollectionsScreen(
            username: state.pathParameters['username']!,
          ),
        ),
      ),
      GoRoute(
        path: '/users/:username',
        pageBuilder: (_, state) => _noTransition(
          state,
          OtherProfileScreen(username: state.pathParameters['username']!),
        ),
      ),
      GoRoute(
        path: '/check-ins/:id',
        pageBuilder: (_, state) => _noTransition(
          state,
          CheckInDetailScreen(checkInId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/beverages/:id',
        pageBuilder: (_, state) => _noTransition(
          state,
          BeverageDetailScreen(beverageId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/breweries/:id',
        pageBuilder: (_, state) => _noTransition(
          state,
          BreweryDetailScreen(breweryId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/beverage-requests/new',
        pageBuilder: (_, state) =>
            _noTransition(state, const SubmitBeverageRequestScreen()),
      ),
    ],
  );
});

/// Re-evaluates the `redirect` whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen<AuthState>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }
  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
