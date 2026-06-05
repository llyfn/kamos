// KAMOS — Root app widget. Wires up the router, theme, and i18n delegates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_toast.dart';
import '../core/i18n/locale_provider.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/notifications/providers/notification_providers.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

/// Global `ScaffoldMessenger` key so the API layer (which lives outside the
/// widget tree) can surface localized snackbars via `apiToastBusProvider`.
final kamosMessengerKey = GlobalKey<ScaffoldMessengerState>();

class KamosApp extends ConsumerWidget {
  const KamosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      title: 'KAMOS',
      debugShowCheckedModeBanner: false,
      theme: buildKamosTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      scaffoldMessengerKey: kamosMessengerKey,
      routerConfig: router,
      builder: (context, child) {
        return _ApiToastListener(
          child: ResumeRefresher(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Refreshes the unread notifications count when the app returns to the
/// foreground. KAMOS doesn't poll — the bottom-tab dot is otherwise updated
/// on tab-focus into Notifications and on mark-read mutations. This adds the
/// third refresh hook called out in design/notifications_ux.md §3.5 ("fetched
/// on app-start and on every tab-focus") so a user who backgrounded the app
/// for hours sees an accurate dot on resume without having to navigate.
///
/// PERF-004: a 30-second debounce skips refreshes on rapid suspend/resume
/// cycles (notification-center pull-down, control-center toggle, screen-lock
/// flicker). The first resume after sign-in always refreshes; subsequent
/// resumes within the window are dropped.
///
/// Public-by-name for `@visibleForTesting` access — the only intended
/// in-app construction site is the [KamosApp.builder] above.
@visibleForTesting
class ResumeRefresher extends ConsumerStatefulWidget {
  const ResumeRefresher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ResumeRefresher> createState() => _ResumeRefresherState();
}

/// Cooldown between consecutive unread-count refreshes triggered by app
/// resume. Anything shorter than this is treated as the same foregrounding
/// event (PERF-004).
@visibleForTesting
const Duration kResumeRefreshDebounce = Duration(seconds: 30);

class _ResumeRefresherState extends ConsumerState<ResumeRefresher>
    with WidgetsBindingObserver {
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final auth = ref.read(authStateProvider);
    if (!auth.isAuthenticated) return;
    final now = DateTime.now();
    final last = _lastRefresh;
    if (last != null && now.difference(last) < kResumeRefreshDebounce) {
      return;
    }
    _lastRefresh = now;
    ref.read(unreadCountProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Listens for transport-level toasts emitted by `AuthInterceptor` and shows
/// the localized copy (`errorUnauthorized`, `errorNetwork`) via the global
/// messenger key. The listener clears the bus after each emission so the same
/// kind can fire again later.
class _ApiToastListener extends ConsumerWidget {
  const _ApiToastListener({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ApiToastKind?>(apiToastBusProvider, (_, next) {
      if (next == null) return;
      final messenger = kamosMessengerKey.currentState;
      if (messenger == null) return;
      final l = AppLocalizations.of(context);
      final message = switch (next) {
        ApiToastKind.unauthorized => l.errorUnauthorized,
        ApiToastKind.network => l.errorNetwork,
        ApiToastKind.notificationsMarkAllFailed =>
          l.notificationsMarkAllError,
        ApiToastKind.notificationsRequestStale =>
          l.notificationsRequestStale,
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      // One-shot semantics: clear so the next 401/network error re-triggers
      // even if the kind is the same.
      ref.read(apiToastBusProvider.notifier).clear();
    });
    // On sign-in transition (false → true), clear any pending API toast and
    // hide any snackbar that's still on screen from the previous session —
    // the previous unauthorized banner must not greet the freshly signed-in
    // user with a stale "Please sign in again."
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (prev == null) return;
      if (!prev.isAuthenticated && next.isAuthenticated) {
        kamosMessengerKey.currentState?.hideCurrentSnackBar(
          reason: SnackBarClosedReason.remove,
        );
        ref.read(apiToastBusProvider.notifier).clear();
      }
    });
    return child;
  }
}
