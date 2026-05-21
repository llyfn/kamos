// KAMOS — Comment exceptions (compat shim).
//
// The canonical definitions live in `core/api/api_exceptions.dart`. This file
// re-exports them so existing imports (`features/comments/exceptions.dart`)
// continue to resolve unchanged. New code should import from the core path.

export '../../core/api/api_exceptions.dart'
    show
        CommentForbiddenException,
        CommentDeletedException,
        CommentTooLongException,
        CommentInvalidBodyException,
        CommentRateLimitedException;
