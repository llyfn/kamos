// Typed venue-search exceptions exposed by `VenueRepository`.
//
// Lives in a leaf file so widgets can pattern-match on the error path
// without importing the repository.

class VenueSearchDisabledException implements Exception {
  const VenueSearchDisabledException();
  @override
  String toString() => 'Venue search is not configured on this server.';
}

class VenueRateLimitedException implements Exception {
  const VenueRateLimitedException();
  @override
  String toString() => 'Venue search rate-limited. Try again shortly.';
}
