---
name: arch-review
description: "Architecture review skill. Analyzes layer separation, coupling, dependency direction, module cohesion, and design pattern correctness. Use when reviewing code structure, system design, or module organization."
---

# Architecture Review Skill

Systematically evaluates the structural integrity of a codebase.

## Review Checklist

### Layer Separation
- [ ] HTTP/transport concerns (request parsing, response writing) stay in handlers — no DB calls in handlers
- [ ] Business rules stay in a service/domain layer — not in handlers or repositories
- [ ] DB queries stay in repositories — no SQL strings in handlers or services
- [ ] UI components (Flutter widgets) contain no HTTP calls or business logic
- [ ] Feature modules do not import each other; shared types live in `shared/`

### Dependency Direction
- [ ] Dependencies point inward: handlers → services → repositories → DB driver
- [ ] No circular imports between packages
- [ ] Interfaces are defined in the package that uses them (Go: dependency inversion)
- [ ] Concretions (DB pool, HTTP client) injected at composition root (`main.go`)

### Coupling & Cohesion
- [ ] Each package/module has a single clear purpose
- [ ] High-change files are isolated from low-change files (stable abstractions principle)
- [ ] Config struct used for all external configuration — no `os.Getenv()` scattered through business logic
- [ ] No god objects (structs/widgets with >10 responsibilities)

### Design Pattern Correctness
- [ ] Repository pattern: returns domain types, not DB-driver types
- [ ] Middleware chain correctly ordered (e.g., logging before auth before business handlers)
- [ ] Riverpod: providers are the single source of truth; no state split between widget `setState` and providers

## Severity Guide

| Severity | Meaning |
|----------|---------|
| HIGH | Makes the system hard to change safely; likely to cause regressions on refactor |
| MEDIUM | Creates maintenance burden; not immediately dangerous |
| LOW | Cosmetic structure issue; fixable opportunistically |

## Output Format

Write findings to `_workspace/review/arch_findings.md`. Use the `[ARCH-NNN]` numbering scheme starting from `ARCH-001`. Group related findings if the same root cause produces multiple symptoms.
