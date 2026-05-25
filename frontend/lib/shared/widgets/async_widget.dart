// KAMOS — AsyncWidget.
//
// Centralizes the conventional `ref.watch(provider).when(...)` shape so
// screens stop hand-rolling LoadingView + ErrorView pairs. Use this when
// the loading and error branches are the project defaults; reach for the
// raw `.when` when a screen needs bespoke UI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'state_views.dart';

/// Renders [data] on success; falls back to [LoadingView] / [ErrorView]
/// (with localized strings) for the other two states.
///
/// Override [loading] or [error] when a screen needs a custom shape (e.g.
/// inline pull-to-refresh on a list footer). Pass [onRetry] to surface a
/// retry button on the default [ErrorView].
class AsyncWidget<T> extends StatelessWidget {
  const AsyncWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
    this.errorMessage,
    this.center = false,
  });

  /// The async state to render.
  final AsyncValue<T> value;

  /// Success builder — receives the resolved data.
  final Widget Function(T data) data;

  /// Custom loading builder. If `null`, [LoadingView] is shown.
  final Widget Function()? loading;

  /// Custom error builder. If `null`, [ErrorView] is shown with
  /// [errorMessage] (or the localized generic-error string).
  final Widget Function(Object err, StackTrace stack)? error;

  /// Optional retry callback wired onto the default [ErrorView]. Ignored
  /// when [error] is supplied.
  final VoidCallback? onRetry;

  /// Optional override for the default [ErrorView]'s message. Defaults to
  /// `AppLocalizations.errorGeneric`.
  final String? errorMessage;

  /// When true, the default loading view is the full-page [LogoLoader]
  /// (centered KAMOS mark with a slow pulse) and the default error view
  /// is wrapped in `Center`. Use for screens that mount this directly
  /// under a Scaffold body. When false, the default loading is the
  /// inline [LoadingView] (small horizontal spinner) — appropriate for
  /// sub-section / list-footer use.
  ///
  /// Custom [loading] / [error] builders are never auto-wrapped or
  /// auto-substituted; pass them when a screen needs bespoke UI.
  final bool center;

  Widget _wrap(Widget child) => center ? Center(child: child) : child;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: loading ??
          () => center ? const LogoLoader() : const LoadingView(),
      error: (e, s) {
        if (error != null) return error!(e, s);
        final l = AppLocalizations.of(context);
        return _wrap(
          ErrorView(
            message: errorMessage ?? l.errorGeneric,
            onRetry: onRetry,
          ),
        );
      },
      data: data,
    );
  }
}
