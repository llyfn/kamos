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
