// Typed comment exceptions exposed by `CommentRepository`.
//
// Lives in a leaf file (per the venues-feature convention) so widgets can
// pattern-match on the error path without importing the repository.

class CommentForbiddenException implements Exception {
  const CommentForbiddenException();
  @override
  String toString() => 'Cannot delete this comment (not the author).';
}

class CommentDeletedException implements Exception {
  const CommentDeletedException();
  @override
  String toString() => 'This comment has already been deleted.';
}

class CommentTooLongException implements Exception {
  const CommentTooLongException();
  @override
  String toString() => 'Comment exceeds the 500-character limit.';
}

/// Body contains a control character disallowed server-side (C0 controls
/// except `\t` / `\n`). Caught locally before the request goes out so the UI
/// can show a dedicated localized message instead of the generic post-failure
/// toast. Mirrors the beverage-request feature's input hygiene.
class CommentInvalidBodyException implements Exception {
  const CommentInvalidBodyException();
  @override
  String toString() => 'Comment contains invalid characters.';
}

/// Server returned 429 (rate-limited). The comment POST endpoint is throttled
/// at 3 rps / burst 6 per user. Surface a dedicated toast so the user knows
/// to slow down rather than seeing the generic post-failure message.
class CommentRateLimitedException implements Exception {
  const CommentRateLimitedException();
  @override
  String toString() => 'Commenting too fast — try again in a moment.';
}
