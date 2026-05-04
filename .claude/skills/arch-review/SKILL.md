---
name: arch-review
description: "Architecture review skill. Analyzes layer separation, dependency direction, coupling, cohesion, missing/premature abstractions, and design pattern correctness in KAMOS code. Use when reviewing structural quality, system design, or module organization. Triggers: architecture review, design review, layer separation, coupling, dependency review."
---

# Architecture Review Skill

Evaluates structural integrity. Catches problems that aren't bugs, security issues, or performance issues — they're problems with how the system is shaped.

## Method

1. Start at the entry point (`cmd/api/main.go`, `lib/main.dart`) and trace outward.
2. Build a mental dependency graph. Flag anything that points the wrong way (a repository importing a handler type, a feature importing another feature directly).
3. For each module, ask: what does this know about? What should it not know about?
4. Identify the seams — where would you split this if one part needed to scale independently?

## Checklist

### Layer separation (Go)

- [ ] Handlers parse requests, call services, format responses — no SQL, no business rules
- [ ] Services hold business rules — no `net/http` types in their signatures
- [ ] Repositories hold SQL — no business rules, no error formatting for the wire
- [ ] Models are domain types, not driver types (no `pgx.Rows` leaking out)
- [ ] `apierror` package owns wire-shape error responses; nothing else writes JSON errors

### Layer separation (Flutter)

- [ ] Widgets call providers; never call Dio or repositories directly
- [ ] Providers wrap repositories; never embed UI types
- [ ] Repositories are the only Dio callers
- [ ] Models do their own JSON parsing; widgets never call `jsonDecode`
- [ ] `features/` modules do not import each other; cross-cutting types live in `shared/`

### Dependency direction

- [ ] Dependencies point inward: handler → service → repository → driver
- [ ] No circular imports
- [ ] Interfaces declared in the package that **uses** them (Go DIP), not where they're implemented
- [ ] Concretions (DB pool, HTTP client, secret store) injected at the composition root (`main.go` / app bootstrap)

### Coupling & cohesion

- [ ] Each package has one clear purpose, expressible in one sentence
- [ ] Config is a single struct loaded at startup; no `os.Getenv` scattered through business logic
- [ ] No god objects (>10 responsibilities)
- [ ] High-change files isolated from stable abstractions

### Design pattern correctness

- [ ] Repository pattern returns domain types, not driver types
- [ ] Middleware chain ordered: recover → log → CORS → rate limit → auth → handler
- [ ] Riverpod: providers are the source of truth; no state split between widget `setState` and providers
- [ ] OAuth flow: Google client secret is server-side only; client ID is the only thing the Flutter app holds

## KAMOS-specific patterns to check

- Handler talking to `pgxpool` directly → violation; must go through repository
- Auth check duplicated in every handler → should be middleware
- i18n fallback (`name_i18n[locale] ?? name_i18n['en']`) implemented in handlers → should be a single helper used everywhere
- Cursor encode/decode duplicated → should live in `pkg/cursor`
- Default collection creation logic duplicated between email and Google registration paths → should be one service function called by both

## Severity guide

| Severity | Meaning |
|---|---|
| HIGH | Makes the system hard to change safely; refactors are likely to cause regressions |
| MEDIUM | Creates maintenance burden; not immediately dangerous |
| LOW | Cosmetic structure issue; address opportunistically |

Architecture reviewer does **not** issue CRITICAL — that's reserved for security findings.

## Output format

Write to `_workspace/review/arch_findings.md` with `[ARCH-NNN]` numbering starting at `ARCH-001`. Group related findings if one root cause produces multiple symptoms.

```markdown
## [ARCH-NNN] Short title
- Severity: HIGH | MEDIUM | LOW
- Location: file:line (or module path)
- Finding: what the problem is
- Impact: what gets harder because of this
- Suggestion: specific structural change
```

## Cross-domain SendMessage

- If a structural finding has a security angle (e.g., auth check duplicated and one variant is missing) → SendMessage `security-reviewer` with the file:line
- If a finding has a perf angle (e.g., N+1 caused by missing batch repository method) → SendMessage `perf-reviewer`
- Receive incoming SendMessage from other reviewers about structural root causes they spotted

When you cross-reference, include the reciprocal finding ID so the orchestrator can dedup in the consolidated report.
