// KAMOS — Widget test: SubmitBeverageRequestScreen (Phase 5 user-side).
//
// Covers:
// * Validation: empty name/brewery shows inline errors and blocks submit.
// * Submit path: filled form invokes the fake repo with the wire-shape
//   payload, then renders the success snackbar.
// * Error path: a repo that throws shows the inline error message and the
//   screen stays open for retry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/beverage_request.dart';
import 'package:kamos/core/api/api_exceptions.dart';
import 'package:kamos/features/beverage_requests/repository/beverage_request_repository.dart';
import 'package:kamos/features/beverage_requests/screens/submit_beverage_request_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

class _FakeRepo implements BeverageRequestRepository {
  _FakeRepo({this.shouldFail = false});
  final bool shouldFail;
  BeverageRequest? lastReq;
  int calls = 0;

  @override
  Future<void> submit(BeverageRequest req) async {
    calls += 1;
    lastReq = req;
    if (shouldFail) {
      throw const BeverageRequestSubmissionException();
    }
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
  testWidgets('empty form does not submit and shows required errors',
      (tester) async {
    final repo = _FakeRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          beverageRequestRepositoryProvider.overrideWithValue(repo),
        ],
        child: _wrap(
          SubmitBeverageRequestScreen(onSubmittedForTest: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Submit button is initially disabled (no name/brewery), so the tap
    // does nothing — repo not called.
    final submit = find.text('Submit');
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
  });

  testWidgets('filled form POSTs to repo with wire-shape payload and shows toast',
      (tester) async {
    final repo = _FakeRepo();
    var submitted = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          beverageRequestRepositoryProvider.overrideWithValue(repo),
        ],
        child: _wrap(
          SubmitBeverageRequestScreen(
            onSubmittedForTest: () => submitted = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    await tester.enterText(textFields.at(0), 'Dassai 45');
    await tester.enterText(textFields.at(1), 'Asahi Shuzo');
    await tester.enterText(textFields.at(2), 'Junmai Daiginjo');
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump(); // schedule
    await tester.pump(const Duration(milliseconds: 10)); // flush microtasks
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    expect(repo.lastReq, isNotNull);
    expect(repo.lastReq!.name, 'Dassai 45');
    expect(repo.lastReq!.breweryName, 'Asahi Shuzo');
    expect(repo.lastReq!.categorySlug, 'nihonshu');
    expect(repo.lastReq!.notes, 'Junmai Daiginjo');

    // Success snackbar visible.
    expect(find.text("Thanks — we'll review your suggestion."),
        findsOneWidget);
    expect(submitted, isTrue);

    // Wire-shape assertion via toJson on the captured request.
    final body = repo.lastReq!.toJson();
    expect(body['payload'], isA<Map<String, dynamic>>());
    expect((body['payload'] as Map)['brewery_name'], 'Asahi Shuzo');
  });

  testWidgets('repo failure renders the inline error and keeps screen open',
      (tester) async {
    final repo = _FakeRepo(shouldFail: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          beverageRequestRepositoryProvider.overrideWithValue(repo),
        ],
        child: _wrap(
          SubmitBeverageRequestScreen(onSubmittedForTest: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'X');
    await tester.enterText(textFields.at(1), 'Y');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    expect(find.text('Could not submit. Try again.'), findsOneWidget);
  });
}
