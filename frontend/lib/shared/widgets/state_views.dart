// KAMOS — Calm loading / empty / error states matching Primitives.jsx.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

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
  });

  final bool isLoading;
  final bool hasMore;

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
            '— ${l.actionEndOfList} —',
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
