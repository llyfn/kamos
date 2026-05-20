// KAMOS — Typed beverage-request submission exceptions (Phase 5 user-side).
//
// Lives in a leaf file so widgets can pattern-match on the error path without
// importing the repository (mirrors `features/venues/exceptions.dart`).
//
// The `POST /v1/beverage-requests` endpoint has no special status-code
// surface — every non-2xx becomes a single `BeverageRequestSubmissionException`
// the UI renders as `submitBeverageRequestErrorGeneric`.

class BeverageRequestSubmissionException implements Exception {
  const BeverageRequestSubmissionException([this.cause]);
  final Object? cause;

  @override
  String toString() => 'BeverageRequestSubmissionException(${cause ?? ''})';
}
