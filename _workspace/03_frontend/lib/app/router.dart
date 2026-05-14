// KAMOS — Application router (go_router).
//
// Paths:
//   /auth                          unauthenticated landing
//   /auth/verify-email             post-registration banner
//   /                              feed (shell root)
//   /search                        discover
//   /check-in                      modal (needs a Beverage extra)
//   /collections                   lists root
//   /collections/:id               detail
//   /me                            self profile
//   /me/edit                       edit profile
//   /me/settings                   settings
//   /inbox                         follow request inbox
//   /users/:username               other user
//   /beverages/:id                 beverage detail
//   /breweries/:id                 brewery detail
//
// Unauthenticated users are redirected to `/auth`; authenticated users on
// `/auth` are redirected to `/`.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/beverage.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/beverages/screens/beverage_detail_screen.dart';
import '../features/breweries/screens/brewery_detail_screen.dart';
import '../features/check_in/screens/check_in_screen.dart';
import '../features/collections/screens/collection_detail_screen.dart';
import '../features/collections/screens/collections_list_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/social/screens/inbox_screen.dart';
import '../shared/widgets/kamos_tab_bar.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final path = state.uri.path;
      final atAuth = path.startsWith('/auth');
      if (!auth.isAuthenticated && !atAuth) return '/auth';
      if (auth.isAuthenticated && atAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(
            path: '/collections',
            builder: (_, __) => const CollectionsListScreen(),
          ),
          GoRoute(path: '/me', builder: (_, __) => const MeProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/check-in',
        builder: (_, state) {
          final b = state.extra as Beverage?;
          if (b == null) {
            // Defensive: if launched without a beverage, bounce back to search.
            return const SearchScreen();
          }
          return CheckInScreen(beverage: b);
        },
      ),
      GoRoute(
        path: '/collections/:id',
        builder: (_, state) => CollectionDetailScreen(
          collectionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/me/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/me/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
      GoRoute(
        path: '/users/:username',
        builder: (_, state) =>
            OtherProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/beverages/:id',
        builder: (_, state) =>
            BeverageDetailScreen(beverageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/breweries/:id',
        builder: (_, state) =>
            BreweryDetailScreen(breweryId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Re-evaluates the `redirect` whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
