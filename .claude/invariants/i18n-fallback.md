---
id: invariant:i18n-fallback
spec: SPEC.md §8
severity_on_violation: MAJOR
layers: [api, flutter]
owners: [backend-engineer, flutter-engineer, i18n-curator, qa-inspector]
---

# i18n fallback

## Rule

When a beverage / producer / collection's `*_i18n` JSONB is missing the user's locale, fall back to `en`. Same rule for `ja → en` and `ko → en`. Never display an empty string. Never display the wrong-locale text.

Fallback lives at **exactly one layer** — preferably the API. Implementing it in both API and UI silently masks bugs; implementing in neither leaves empty strings.

## Check

```bash
# Helper exists once in Go
grep -rn "ResolveI18n\|i18nFallback\|resolveLocale" backend/internal/

# Helper is the only resolver — handlers do not inline locale lookups
grep -rn "name_i18n\[\|nameI18n\[" backend/internal/handlers/

# Flutter does not duplicate the fallback (would mask backend bugs)
grep -rn "\\['en'\\]\\s*??\\|nameI18n\\[\\|name_i18n\\[" frontend/lib/
```

## Where each layer enforces it

- **API** — helper in `backend/internal/domain/` (or `backend/internal/service/`) called by every read endpoint that returns localized text. Handlers never inline `name_i18n[locale] ?? name_i18n['en']`.
- **Flutter** — model receives the already-resolved string. Does **not** re-resolve.
- **Seed names** — [[invariant:default-collections]] seeds use the locale-resolved value at registration time.

## Related

- [[invariant:category-strings]] — category strings are present in all three locales (no fallback needed)
- [[invariant:default-collections]] — collection seed names use this fallback
