// KAMOS — Calm loading / empty / error states matching Primitives.jsx.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Full-page loading state: the KAMOS cheers mark, centered, with a slow
/// opacity pulse to signal that something is happening. Use this for
/// page-level boot loaders (initial fetches that fill the screen).
///
/// For inline / footer / sub-section loading, prefer [LoadingView] (the
/// small horizontal spinner) — the logo is overkill in tight spaces.
/// [AsyncWidget] picks between the two automatically based on its
/// `center` flag.
class LogoLoader extends StatefulWidget {
  const LogoLoader({super.key, this.size = 96});

  /// Width and height in logical pixels. Defaults to 96 — the asset
  /// renders cleanly at that size on every iPhone density bucket.
  final double size;

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: Image.asset(
          'assets/images/logo_mark.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(t.ai),
              backgroundColor: t.gray200,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            (label ?? l.loadingLabel).toUpperCase(),
            style: TextStyle(
              fontFamily: 'NotoSansJP',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              color: t.fg3,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.glyph, this.title, this.body, this.action});

  final String? glyph;
  final String? title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (glyph != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                glyph!,
                style: TextStyle(
                  fontFamily: 'ShipporiMincho',
                  fontSize: 48,
                  height: 1.0,
                  color: t.gray300,
                ),
              ),
            ),
          if (title != null)
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: t.fg1,
              ),
            ),
          if (body != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  fontSize: 14,
                  height: 1.55,
                  color: t.fg2,
                ),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message ?? l.errorGeneric,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  fontSize: 14,
                  color: t.fg2,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                Text(
                  l.actionRetry.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: t.fgLink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PagingFooter extends StatelessWidget {
  const PagingFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.endLabel,
  });

  final bool isLoading;
  final bool hasMore;

  /// Optional override for the "End of list" caption. Defaults to
  /// [AppLocalizations.actionEndOfList] when null. The notifications screen
  /// passes [AppLocalizations.notificationsEnd] ("You're all caught up.")
  /// per design/notifications_ux.md §1.1.
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isLoading) return LoadingView(label: l.actionLoadingMore);
    if (!hasMore) {
      final t = context.tokens;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Center(
          child: Text(
            '— ${endLabel ?? l.actionEndOfList} —',
            style: TextStyle(
              fontFamily: 'NotoSansJP',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              color: t.fg3,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
