---
name: flutter-feature
description: "KAMOS Flutter feature development skill. Use this to implement Flutter screens, Riverpod providers, go_router navigation, ARB-based i18n (en/ja/ko), the Dio repository layer, and widget components for the KAMOS mobile app. Invoke whenever Flutter screen implementation, widget building, state management, navigation, secure storage, or localization work is requested. Triggers: Flutter, Dart, widget, screen, Riverpod, go_router, ARB, i18n, mobile."
---

# Flutter Feature Skill

Implements features in the KAMOS Flutter app: screens, providers, navigation, API integration, secure storage, and i18n.

## Project structure

```
frontend/
├── lib/
│   ├── main.dart
│   ├── app/                — app widget, router, theme, providers
│   ├── features/           — feature-first: auth/, beverage/, checkin/, feed/, profile/, collection/
│   ├── shared/             — widgets/, models/, services/, utils/
│   └── l10n/               — generated code (do not edit)
├── l10n/                   — ARB files: app_en.arb, app_ja.arb, app_ko.arb
├── android/, ios/
└── pubspec.yaml
```

Each feature folder contains: `screens/`, `widgets/`, `providers/`, `repositories/`.

Write production code to `frontend/`. There is no workspace fallback.

## SPEC invariants the app must respect

| SPEC | Invariant | Where |
|---|---|---|
| §2.1 | Category strings exact: `Nihonshu (Sake)` / `Shochu` / `Liqueur` (en); `日本酒` / `焼酎` / `リキュール` (ja); `니혼슈 (사케)` / `쇼츄` / `리큐어` (ko) | All three ARB files |
| §3.1 | JWT in `flutter_secure_storage`, never `SharedPreferences` | Auth service / interceptor |
| §3.2 | Username case-insensitive (display as-stored, compare lowercase) | Profile screen / search |
| §4.1 | ≤ 4 photos, ≤ 500 char review | Check-in form (block client-side; server is backstop) |
| §4.2 | 0.5-step rating widget, 10 levels (0.5–5.0) | Star widget |
| §5.2 | Cursor pagination via `next_cursor` + `has_more` | Every list repository |
| §6.1 | Inventory + Wishlist created server-side; client just renders the user's collections | Collection screen |
| §8 | If `name_i18n[user.locale]` missing, fall back to `en` | Beverage name resolver |

## State management — Riverpod

Prefer code-gen (`riverpod_generator`) when build_runner is available; fall back to manual `Notifier`/`AsyncNotifier` syntax otherwise.

```dart
// providers/checkin_provider.dart  — generated style
@riverpod
class CheckInController extends _$CheckInController {
  @override
  FutureOr<void> build() {}

  Future<void> submit(CheckInFormData form) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(checkInRepositoryProvider).create(form),
    );
  }
}

// providers/beverage_detail_provider.dart  — async fetched data
@riverpod
Future<Beverage> beverageDetail(BeverageDetailRef ref, String id) async {
  return ref.read(beverageRepositoryProvider).getBeverage(id);
}
```

Rules:

- Widgets call providers via `ref.watch` / `ref.read`; widgets never call repositories directly.
- For lists shown inside `ListView.builder`, use `.select((s) => s.specificField)` to narrow rebuild scope.
- Heavy computation lives in providers, never in `build()`.

## Repository layer

Repositories are the only place that touches Dio. Models do their own JSON parsing (via `freezed` + `json_serializable`).

```dart
// repositories/beverage_repository.dart
class BeverageRepository {
  BeverageRepository(this._dio);
  final Dio _dio;

  Future<Beverage> getBeverage(String id) async {
    final res = await _dio.get('/beverages/$id');
    return Beverage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Page<Checkin>> getFeed({String? cursor}) async {
    final res = await _dio.get('/feed', queryParameters: {
      if (cursor != null) 'cursor': cursor,
    });
    return Page.fromJson(res.data as Map<String, dynamic>, Checkin.fromJson);
  }
}

final beverageRepositoryProvider = Provider(
  (ref) => BeverageRepository(ref.watch(dioProvider)),
);
```

Use `ref.watch(dioProvider)` (not `read`). When the user logs out, `dioProvider` is invalidated; `watch` makes every repository rebuild against the fresh Dio (and its fresh `AuthInterceptor` + `MemCacheStore`), which is what prevents cross-user data leaks. See `frontend/lib/features/auth/providers/auth_state.dart` for the invalidation chain.

`Page<T>` is a shared model matching the Go `pkg/cursor.Page[T]` shape:

```dart
@freezed
class Page<T> with _$Page<T> {
  const factory Page({
    required List<T> items,
    String? nextCursor,
    @Default(false) bool hasMore,
  }) = _Page<T>;

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) =>
      Page(
        items: (json['items'] as List).map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: (json['has_more'] as bool?) ?? false,
      );
}
```

## Dio client + interceptors

```dart
// shared/services/api_client.dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(AuthInterceptor(ref));
  if (kDebugMode) dio.interceptors.add(LogInterceptor(responseBody: true));
  return dio;
});

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);
  final Ref _ref;

  @override
  Future<void> onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    final token = await _ref.read(secureStorageProvider).readToken();
    if (token != null) o.headers['Authorization'] = 'Bearer $token';
    h.next(o);
  }

  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler h) async {
    if (e.response?.statusCode == 401) {
      await _ref.read(authControllerProvider.notifier).logout();
    }
    h.next(e);
  }
}
```

Token storage MUST use `flutter_secure_storage`:

```dart
// shared/services/secure_storage_service.dart
class SecureStorageService {
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> writeToken(String token) => _store.write(key: 'jwt', value: token);
  Future<String?> readToken() => _store.read(key: 'jwt');
  Future<void> clear() => _store.delete(key: 'jwt');
}
```

Anything reading/writing `jwt` from `SharedPreferences` is a security blocker — qa-inspector will grep for it.

## Screen template

```dart
class BeverageDetailScreen extends ConsumerWidget {
  const BeverageDetailScreen({required this.beverageId, super.key});
  final String beverageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(beverageDetailProvider(beverageId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.beverageDetailTitle)),
      body: state.when(
        loading: () => const BeverageDetailSkeleton(),
        error: (e, _) => ErrorState(
          message: l10n.genericError,
          onRetry: () => ref.invalidate(beverageDetailProvider(beverageId)),
        ),
        data: (bev) => BeverageDetailBody(beverage: bev),
      ),
    );
  }
}
```

Every async screen must handle all three states: loading skeleton, error with retry, success.

## go_router configuration

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) {
      final loggedIn = ref.read(authStateProvider).isLoggedIn;
      final atAuth = state.uri.path.startsWith('/auth');
      if (!loggedIn && !atAuth) return '/auth/login';
      if (loggedIn && atAuth) return '/feed';
      return null;
    },
    routes: [
      GoRoute(path: '/auth/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/auth/verify',   builder: (_, s) => VerifyEmailScreen(token: s.uri.queryParameters['token'])),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/feed',                  builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/search',                builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/beverages/:id',         builder: (_, s) => BeverageDetailScreen(beverageId: s.pathParameters['id']!)),
          GoRoute(path: '/breweries/:id',         builder: (_, s) => BreweryDetailScreen(breweryId: s.pathParameters['id']!)),
          GoRoute(path: '/checkin/new',           builder: (_, s) => CheckInFormScreen(beverageId: s.uri.queryParameters['beverage_id'])),
          GoRoute(path: '/checkins/:id',          builder: (_, s) => CheckInDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/profile/:username',     builder: (_, s) => ProfileScreen(username: s.pathParameters['username']!)),
          GoRoute(path: '/collections',           builder: (_, __) => const CollectionListScreen()),
          GoRoute(path: '/collections/:id',       builder: (_, s) => CollectionDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/settings',              builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/follow-requests',       builder: (_, __) => const FollowRequestsScreen()),
        ],
      ),
    ],
  );
});
```

**Profile navigation** — call `pushUserProfile(context, username)` from `lib/features/users/navigation.dart` rather than `context.push('/users/$username')` directly. The helper detects self-navigation (`username == me.user.username`) and uses `context.go('/me')` so the navigator never stacks a duplicate `NoTransitionPage` on top of the existing `/me` shell tab — pushing `/users/:self` would otherwise crash with `keyReservation.contains(key) is not true`.

qa-inspector will check that every path here corresponds to a real screen file.

## i18n — ARB files

Three files, all updated together:

```json
// l10n/app_en.arb
{
  "@@locale": "en",
  "categoryNihonshu":  "Nihonshu (Sake)",
  "categoryShochu":    "Shochu",
  "categoryLiqueur":   "Liqueur",
  "feedTitle":         "Feed",
  "checkInRating":     "Rating",
  "ratingValue":       "{value} / 5.0",
  "@ratingValue":      { "placeholders": { "value": { "type": "double", "format": "decimalPattern" } } }
}
```

```json
// l10n/app_ja.arb
{
  "@@locale": "ja",
  "categoryNihonshu":  "日本酒",
  "categoryShochu":    "焼酎",
  "categoryLiqueur":   "リキュール"
}
```

```json
// l10n/app_ko.arb
{
  "@@locale": "ko",
  "categoryNihonshu":  "니혼슈 (사케)",
  "categoryShochu":    "쇼츄",
  "categoryLiqueur":   "리큐어"
}
```

Rules:

- Never hardcode display strings in widgets — always `l10n.foo`.
- Category names match the SPEC table EXACTLY. qa-inspector greps for divergence.
- Add a key to all three files in the same change. Missing keys in ja or ko are blockers.
- For beverage `name_i18n` from the API, write a small resolver: `bev.localized(locale).name ?? bev.name['en']`.

## Star rating widget — 0.5 step

10 levels: 0.5, 1.0, 1.5, ..., 5.0. The widget is a `Row` of 5 star icons; each icon is a `GestureDetector` whose tap-position maps to half-star precision:

```dart
class StarRatingPicker extends StatelessWidget {
  const StarRatingPicker({required this.value, required this.onChanged, super.key});
  final double? value; // null = unrated
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (value ?? 0) - i;
        final icon = fill >= 1 ? Icons.star
                   : fill >= 0.5 ? Icons.star_half
                   : Icons.star_border;
        return GestureDetector(
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox;
            final localX = d.localPosition.dx;
            final isLeftHalf = localX < box.size.width / 2;
            onChanged(i + (isLeftHalf ? 0.5 : 1.0));
          },
          child: Icon(icon, size: 32),
        );
      }),
    );
  }
}
```

Never round to integer. Never use 0.25 steps (Untappd does; KAMOS does not — see SPEC §4.2).

## Check-in form — the most complex flow

1. `BeverageSearchDelegate` → user picks a beverage → captures `beverageId`.
2. Navigate to `/checkin/new?beverage_id=...`.
3. Form: `StarRatingPicker` (optional), review text (max 500), flavor tag chips (multi-select from server-provided taxonomy), photo picker (max 4, enforced client-side), price + currency + per-serving toggle, purchase type, serving style.
4. Submit → `CheckInController.submit()` → on success, navigate to `/checkins/:newId`.

Block submission of >4 photos client-side; show a snackbar. Server is backstop.

## pubspec.yaml baseline

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^14.0.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  google_sign_in: ^6.2.0
  image_picker: ^1.1.0
  cached_network_image: ^3.3.0
  intl: ^0.19.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  flutter_lints: ^4.0.0
```

Do not add new dependencies without asking.

## Output checklist

- [ ] Every screen has loading / error / data states
- [ ] No widget calls Dio or HTTP directly
- [ ] No `print()` left in code
- [ ] No hardcoded display strings; all via `l10n.*`
- [ ] All three ARB files have matching keys
- [ ] Category strings match SPEC §2.1 exactly
- [ ] Token reads/writes go through `SecureStorageService` (never SharedPreferences)
- [ ] Lists use `ListView.builder` with `next_cursor`-driven infinite scroll
- [ ] Network images use `CachedNetworkImage`
- [ ] Star rating widget produces 0.5-step values
