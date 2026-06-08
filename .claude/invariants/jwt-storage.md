---
id: invariant:jwt-storage
spec: SPEC.md §3.1, §6.9
severity_on_violation: BLOCKER
layers: [flutter, ios, android]
owners: [flutter-engineer, security-reviewer, qa-inspector]
---

# JWT secure storage

## Rule

JWT and refresh token live in `flutter_secure_storage` only. Never `SharedPreferences`, never `Hive`, never in-memory beyond the current process. On iOS, Keychain accessibility is `first_unlock_this_device` (Stage 0 hotfix; no exceptions). Refresh tokens rotate atomically in a single transaction; family revocation on detected reuse.

## Check

```bash
# Any match → BLOCKER
grep -rn "SharedPreferences" frontend/lib/ | grep -i "token\|jwt\|auth\|refresh"

# iOS Keychain accessibility must be first_unlock_this_device
grep -rn "first_unlock_this_device\|firstUnlockThisDevice" frontend/lib/ frontend/ios/
```

## Where each layer enforces it

- **Flutter** — `frontend/lib/features/auth/services/` (token storage, interceptor); auth interceptor reads from secure storage only.
- **iOS** — `flutter_secure_storage` initialized with `IOSAccessibility.first_unlock_this_device`.
- **Backend** — refresh rotation is atomic (single transaction); family revocation on reuse. See `backend/internal/auth/`.
- **Backend (SEC-006)** — soft-deleted user IDs cached in-process so verification rejects them during the 30-day username-hold window. See [[invariant:soft-delete]].

## Related

- [[invariant:soft-delete]] — soft-delete cache feeds JWT verification path
- [[invariant:admin-auth]] — admin uses HttpOnly cookies, not Bearer; do not mix
