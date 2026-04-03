---
name: flutter-feature
description: "KAMOS Flutter feature development skill. Use this to implement Flutter screens, Riverpod providers, Go Router navigation, i18n ARB files, HTTP repository layer, and widget components for the KAMOS mobile app. Invoke whenever Flutter screen implementation, widget building, state management, navigation, or localization work is requested."
---

# Flutter Feature Skill

Implements Flutter features for KAMOS: screens, providers, navigation, API integration, and i18n.

## Feature Implementation Pattern

Each feature in `lib/features/{name}/` follows this structure:
```
features/auth/
├── screens/
│   ├── login_screen.dart
│   └── register_screen.dart
├── widgets/
│   └── social_login_button.dart
├── providers/
│   └── auth_provider.dart
└── repositories/
    └── auth_repository.dart
```

## Riverpod Provider Pattern

```dart
// providers/checkin_provider.dart
@riverpod
class CheckInNotifier extends _$CheckInNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> submit(CheckInFormData form) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(checkInRepositoryProvider).create(form),
    );
  }
}

// For fetched data:
@riverpod
Future<Beverage> beverageDetail(BeverageDetailRef ref, String id) async {
  return ref.read(beverageRepositoryProvider).getBeverage(id);
}
```

## Repository Pattern

```dart
// repositories/beverage_repository.dart
class BeverageRepository {
  final Dio _dio;
  BeverageRepository(this._dio);

  Future<Beverage> getBeverage(String id) async {
    final res = await _dio.get('/beverages/$id');
    return Beverage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PaginatedResult<CheckIn>> getFeed({String? cursor}) async {
    final res = await _dio.get('/feed', queryParameters: {'cursor': cursor});
    return PaginatedResult.fromJson(res.data, CheckIn.fromJson);
  }
}

final beverageRepositoryProvider = Provider((ref) =>
  BeverageRepository(ref.read(dioProvider)));
```

## Dio Client Setup

```dart
// shared/services/api_client.dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  dio.interceptors.add(AuthInterceptor(ref));  // injects Bearer token
  dio.interceptors.add(LogInterceptor());
  return dio;
});

class AuthInterceptor extends Interceptor {
  void onRequest(options, handler) async {
    final token = await SecureStorageService.getToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
  void onError(err, handler) {
    if (err.response?.statusCode == 401) {
      // trigger logout
    }
    handler.next(err);
  }
}
```

## Screen Template

```dart
class BeverageDetailScreen extends ConsumerWidget {
  final String beverageId;
  const BeverageDetailScreen({required this.beverageId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final beverage = ref.watch(beverageDetailProvider(beverageId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.beverageDetailTitle)),
      body: beverage.when(
        loading: () => const BeverageDetailSkeleton(),
        error: (e, _) => ErrorState(message: l10n.genericError, onRetry: () => ref.refresh(beverageDetailProvider(beverageId))),
        data: (bev) => BeverageDetailBody(beverage: bev),
      ),
    );
  }
}
```

## i18n (ARB) Pattern

Three files: `l10n/app_en.arb`, `l10n/app_ja.arb`, `l10n/app_ko.arb`

```json
// app_en.arb
{
  "@@locale": "en",
  "beverageCategoryNihonshu": "Nihonshu (Sake)",
  "beverageCategoryShochu": "Shochu",
  "checkInRating": "Rating",
  "feedTitle": "Feed"
}
// app_ko.arb
{
  "@@locale": "ko",
  "beverageCategoryNihonshu": "니혼슈 (사케)",
  "beverageCategoryShochu": "쇼츄"
}
// app_ja.arb
{
  "@@locale": "ja",
  "beverageCategoryNihonshu": "日本酒",
  "beverageCategoryShochu": "焼酎"
}
```

Rules:
- NEVER hardcode display strings in widgets — always use `l10n.keyName`
- Category names must exactly match README terminology
- Add keys to all three ARB files in the same commit

## Go Router Configuration

```dart
// app/router.dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
      if (!isLoggedIn && !state.uri.path.startsWith('/auth')) return '/auth/login';
      return null;
    },
    routes: [
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/beverages/:id', builder: (_, state) =>
            BeverageDetailScreen(beverageId: state.pathParameters['id']!)),
          GoRoute(path: '/checkin/new', builder: (_, state) =>
            CheckInFormScreen(beverageId: state.uri.queryParameters['beverage_id'])),
          GoRoute(path: '/profile/:username', builder: (_, state) =>
            ProfileScreen(username: state.pathParameters['username']!)),
          GoRoute(path: '/collection', builder: (_, __) => const CollectionScreen()),
        ],
      ),
    ],
  );
});
```

## Check-In Form

The check-in form is the most complex flow:
1. `BeverageSearchDelegate` → user selects beverage
2. Navigate to `CheckInFormScreen` with `beverageId`
3. Form fields: star rating (0.5 step), review text, flavor tag chips, optional photo, venue search, price
4. Submit → `CheckInNotifier.submit()` → navigate to check-in detail on success

Star rating widget: implement as a `GestureDetector` on a `Row` of half-star icons (0.5 step via detecting tap position).

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^14.0.0
  riverpod: ^2.5.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  google_sign_in: ^6.2.0
  image_picker: ^1.1.0
  cached_network_image: ^3.3.0
  intl: ^0.19.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  json_serializable: ^6.7.0
  freezed: ^2.4.0
```
