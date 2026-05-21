// KAMOS — Venue search providers.
//
// `venueSearchProvider` owns the in-flight search future and a 300ms
// debounce. Callers push a query through `notifier.setQuery(...)`; the
// notifier coalesces typing bursts and only fires one request per "settled"
// query.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/venue.dart';
import '../repository/venue_repository.dart';

const venueSearchDebounce = Duration(milliseconds: 300);

class VenueSearchQuery {
  const VenueSearchQuery({
    this.text = '',
    this.lat,
    this.lng,
    this.locale = 'en',
  });

  final String text;
  final double? lat;
  final double? lng;
  final String locale;

  bool get isEmpty => text.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is VenueSearchQuery &&
      other.text == text &&
      other.lat == lat &&
      other.lng == lng &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(text, lat, lng, locale);
}

class VenueSearchNotifier extends AsyncNotifier<List<FoursquarePlace>> {
  Timer? _debounce;
  int _epoch = 0;
  VenueSearchQuery _query = const VenueSearchQuery();

  @override
  Future<List<FoursquarePlace>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  VenueSearchQuery get query => _query;

  /// Push a new query. Debounced by [venueSearchDebounce]. Empty queries
  /// short-circuit to an empty list with no network call.
  void setQuery(VenueSearchQuery q) {
    // PERF-013: skip identical re-emits (IME composition often fires the
    // same text repeatedly). Cheap equality check before any work.
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    if (q.isEmpty) {
      _epoch += 1;
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    _debounce = Timer(venueSearchDebounce, () => _run(q));
  }

  Future<void> _run(VenueSearchQuery q) async {
    final epoch = ++_epoch;
    try {
      final results = await ref
          .read(venueRepositoryProvider)
          .search(query: q.text, lat: q.lat, lng: q.lng, locale: q.locale);
      if (epoch != _epoch) return;
      state = AsyncValue.data(results);
    } catch (e, st) {
      if (epoch != _epoch) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final venueSearchProvider =
    AsyncNotifierProvider.autoDispose<
      VenueSearchNotifier,
      List<FoursquarePlace>
    >(VenueSearchNotifier.new);
