---
id: invariant:default-collections
spec: SPEC.md §6.1
severity_on_violation: BLOCKER
layers: [api, schema]
owners: [backend-engineer, db-architect, qa-inspector]
---

# Default collections

## Rule

Every new user is created with two collections: `Inventory` and `Wishlist`. They are renameable and deletable; they are not special. The seeded names are localized per the registering user's `locale` (Stage 5).

The user row and the two collection rows are inserted in **the same transaction** as the registration. Both the email/password path and the Google OAuth path must do this.

## Check

```bash
# Both registration handlers must seed collections atomically
grep -rn "Inventory\|Wishlist" backend/internal/handlers/auth*.go backend/internal/handlers/users*.go backend/internal/service/

# Look for the localization map (ja: '在庫', 'ウィッシュリスト' / ko: '재고', '위시리스트' / en literal)
grep -rn "在庫\|재고\|ウィッシュリスト\|위시리스트" backend/internal/

# Repository: single-tx insert
grep -rn "BEGIN\|Begin(ctx" backend/internal/repository/users*.go backend/internal/repository/collections*.go
```

## Where each layer enforces it

- **Service** — `backend/internal/service/users*.go` (or auth service) wraps user + 2 collection inserts in one `BEGIN ... COMMIT`.
- **Both registration paths** — email/password handler and Google OAuth handler call the same service function. No parallel implementation.
- **Locale-aware seed** — the seed name is selected from the user's chosen locale; see [[invariant:i18n-fallback]] for the fallback rule when the seed locale is missing a translation.

## Related

- [[invariant:i18n-fallback]] — locale fallback rule applies to the seed names
- [[invariant:soft-delete]] — collections soft-delete via `deleted_at TIMESTAMPTZ`
