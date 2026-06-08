---
id: invariant:category-strings
spec: SPEC.md §2.1, §8
severity_on_violation: BLOCKER
layers: [flutter, admin, designer, i18n]
owners: [designer, flutter-engineer, i18n-curator, qa-inspector]
---

# Category strings (exact)

## Rule

The three top-level alcohol categories use these strings exactly. Never abbreviate. Never substitute `Sake` alone in `en`.

| Locale | Sake | Shochu | Liqueur |
|---|---|---|---|
| `en` | `Nihonshu (Sake)` | `Shochu` | `Liqueur` |
| `ja` | `日本酒` | `焼酎` | `リキュール` |
| `ko` | `니혼슈 (사케)` | `쇼츄` | `리큐어` |

Strings live in ARB files; UI code never hardcodes them.

## Check

```bash
# Hardcoded matches outside ARB → BLOCKER
grep -rn "Nihonshu\|Shochu\|Liqueur" frontend/lib/ | grep -v ".arb"
grep -rn "日本酒\|焼酎\|リキュール" frontend/lib/ | grep -v ".arb"
grep -rn "니혼슈\|쇼츄\|리큐어" frontend/lib/ | grep -v ".arb"

# Standalone "Sake" in en ARB (must be Nihonshu (Sake)) → BLOCKER
grep -n '"Sake"\|: "Sake' frontend/l10n/intl_en.arb

# Admin web surface
grep -rn "Nihonshu\|Shochu\|Liqueur\|日本酒\|焼酎\|リキュール\|니혼슈\|쇼츄\|리큐어" admin/src/ | grep -vE "\.(json|test|spec)\."
```

## Where each layer enforces it

- **ARB** — `frontend/l10n/intl_en.arb`, `intl_ja.arb`, `intl_ko.arb`. All three locales updated together; never partial.
- **Flutter UI** — references the localization getter, never the literal string.
- **Admin** — same rule; admin's locale layer mirrors the ARB.
- **Design** — `design/ui_kits/mobile/` and Figma sources use the exact strings; designer flags any drift to flutter-engineer.

## Related

- [[invariant:i18n-fallback]] — missing locale falls back to `en` (but category names must be present in every locale)
