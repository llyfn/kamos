// KAMOS — Beverage request submission exception (compat shim).
//
// The canonical definition lives in `core/api/api_exceptions.dart`. This file
// re-exports it so existing imports
// (`features/beverage_requests/exceptions.dart`) continue to resolve
// unchanged. New code should import from the core path.

export '../../core/api/api_exceptions.dart'
    show BeverageRequestSubmissionException;
