// KAMOS — Widget test: VenuePickerSheet renders search results and pops
// with the chosen FoursquarePlace on tap.
//
// The repository is overridden via `venueRepositoryProvider`. The debounce
// timer in the search notifier is real (300ms), so the test pumps past it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/venue.dart';
import 'package:kamos/features/venues/repository/venue_repository.dart';
import 'package:kamos/features/venues/widgets/venue_picker_sheet.dart';
import 'package:kamos/l10n/app_localizations.dart';

class _StubVenueRepo implements VenueRepository {
  _StubVenueRepo(this.places);
  final List<FoursquarePlace> places;
  String? lastQuery;
  int calls = 0;

  @override
  Future<List<FoursquarePlace>> search({
    required String query,
    double? lat,
    double? lng,
    String locale = 'en',
  }) async {
    calls += 1;
    lastQuery = query;
    return places;
  }
}

const _places = <FoursquarePlace>[
  FoursquarePlace(
    foursquareId: 'fsq-1',
    name: 'Daikoku',
    address: '1-2-3 Shibuya',
    lat: 35.6595,
    lng: 139.7005,
    country: 'JP',
    prefecture: 'Tokyo',
    locality: 'Shibuya',
  ),
  FoursquarePlace(
    foursquareId: 'fsq-2',
    name: 'Sakura Bar',
    locality: 'Shinjuku',
    country: 'JP',
  ),
];

class _Host extends StatefulWidget {
  const _Host({required this.onPicked});
  final void Function(FoursquarePlace? p) onPicked;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    // Open the sheet as soon as the first frame is painted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final picked = await showVenuePicker(context);
      widget.onPicked(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  testWidgets(
      'typing a query renders the stub results and tapping a row pops the place',
      (tester) async {
    final repo = _StubVenueRepo(_places);
    FoursquarePlace? captured;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(repo),
        ],
        child: _wrap(_Host(onPicked: (p) => captured = p)),
      ),
    );
    // Open the sheet (PostFrameCallback in _Host).
    await tester.pump();
    await tester.pumpAndSettle();

    // Empty-state hint visible before typing.
    expect(find.text('Search for a bar, restaurant, or shop.'),
        findsOneWidget);

    // Type the query, then advance past the 300ms debounce.
    await tester.enterText(find.byType(TextField), 'daikoku');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repo.calls, greaterThanOrEqualTo(1));
    expect(repo.lastQuery, 'daikoku');

    // Both rows render.
    expect(find.text('Daikoku'), findsOneWidget);
    expect(find.text('Sakura Bar'), findsOneWidget);

    // Tap the first row.
    await tester.tap(find.text('Daikoku'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.foursquareId, 'fsq-1');
    expect(captured!.name, 'Daikoku');
  });
}
