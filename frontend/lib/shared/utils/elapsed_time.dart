// KAMOS — "2h ago" elapsed-time formatter for the feed.
//
// Outputs a locale-tolerant short form using small numeric strings. Not full
// `intl.RelativeDateTime`, but matches the Untappd-like brevity in the kit.

import '../../l10n/app_localizations.dart';

String elapsedShort(DateTime when, AppLocalizations l) {
  final now = DateTime.now();
  final diff = now.difference(when);

  if (diff.inSeconds < 60) return _now(l);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
  return '${(diff.inDays / 365).floor()}y';
}

String _now(AppLocalizations l) {
  // The "just now" string lives in the app's locale via fallback; for now we
  // hardcode minimal text since the ARB does not yet have a dedicated key.
  return 'now';
}

DateTime? parseIsoDateOrNull(String raw) {
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
