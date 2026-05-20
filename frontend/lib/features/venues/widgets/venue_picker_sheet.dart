// KAMOS — Venue picker bottom sheet (Phase 4).
//
// Triggered from the check-in screen via [showVenuePicker]. Wraps a search
// field, a results list, and the 503 handling for VENUE_SEARCH_DISABLED and
// VENUE_RATE_LIMITED. Returns the picked `FoursquarePlace` (or null).
//
// Layer separation: this widget only talks to `venueSearchProvider`. The
// provider talks to `VenueRepository`. Dio is invisible from here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/venue.dart';
import '../../../l10n/app_localizations.dart';
import '../exceptions.dart';
import '../providers/venue_providers.dart';

/// Sheet renders at most this many; results past ~30 lose discoverability
/// without a map view (Phase 4 has no map). The server still returns up
/// to 20 (was 50 — see Phase 4 review SEC-007/SEC-004), so this UI cap
/// only kicks in if the backend's limit is raised later.
const _maxResultsOnScreen = 30;

/// Opens the venue picker sheet. Returns the chosen place, or null if the
/// sheet was dismissed without a selection.
Future<FoursquarePlace?> showVenuePicker(BuildContext context) {
  return showModalBottomSheet<FoursquarePlace>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const VenuePickerSheet(),
  );
}

class VenuePickerSheet extends ConsumerStatefulWidget {
  const VenuePickerSheet({super.key});

  @override
  ConsumerState<VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends ConsumerState<VenuePickerSheet> {
  final _controller = TextEditingController();
  String _locale = 'en';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = Localizations.localeOf(context).languageCode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    ref.read(venueSearchProvider.notifier).setQuery(
          VenueSearchQuery(text: text, locale: _locale),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: l.venuePickerSearchPlaceholder,
                    prefixIcon: Icon(Icons.search, color: t.fg3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                // PERF-014: scope `venueSearchProvider` watch to this
                // subtree so the parent (incl. TextField) does not rebuild
                // on every notifier transition (loading → data/error).
                child: Consumer(
                  builder: (context, ref, _) {
                    final results = ref.watch(venueSearchProvider);
                    return _Results(
                      controller: scrollController,
                      results: results,
                      query: _controller.text,
                      onPick: (place) => Navigator.of(context).pop(place),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.controller,
    required this.results,
    required this.query,
    required this.onPick,
  });

  final ScrollController controller;
  final AsyncValue<List<FoursquarePlace>> results;
  final String query;
  final void Function(FoursquarePlace) onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;

    if (query.trim().isEmpty) {
      return _Centered(
        child: Text(
          l.venuePickerEmptyHint,
          style: TextStyle(color: t.fg2),
          textAlign: TextAlign.center,
        ),
      );
    }

    return results.when(
      loading: () => const _Centered(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (err, _) {
        if (err is VenueSearchDisabledException) {
          return _Centered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.venuePickerDisabled,
                  style: TextStyle(color: t.fg2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.actionCancel),
                ),
              ],
            ),
          );
        }
        if (err is VenueRateLimitedException) {
          return _Centered(
            child: Text(
              l.venuePickerRateLimited,
              style: TextStyle(color: t.fg2),
              textAlign: TextAlign.center,
            ),
          );
        }
        return _Centered(
          child: Text(
            l.errorGeneric,
            style: TextStyle(color: t.fg2),
            textAlign: TextAlign.center,
          ),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return _Centered(
            child: Text(
              l.venuePickerNoResults,
              style: TextStyle(color: t.fg2),
              textAlign: TextAlign.center,
            ),
          );
        }
        final visible =
            items.length > _maxResultsOnScreen
                ? items.sublist(0, _maxResultsOnScreen)
                : items;
        return ListView.separated(
          controller: controller,
          itemCount: visible.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: t.border1),
          itemBuilder: (context, i) {
            final place = visible[i];
            final secondary = _secondaryLine(place);
            return ListTile(
              title: Text(place.name),
              subtitle: secondary == null ? null : Text(secondary),
              trailing: Icon(Icons.chevron_right, color: t.fg3),
              onTap: () => onPick(place),
            );
          },
        );
      },
    );
  }

  String? _secondaryLine(FoursquarePlace p) {
    if ((p.address ?? '').isNotEmpty) return p.address;
    final parts = <String>[
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.country ?? '').isNotEmpty) p.country!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: child),
    );
  }
}
