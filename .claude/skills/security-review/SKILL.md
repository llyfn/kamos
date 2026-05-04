---
name: security-review
description: "Security vulnerability review skill. Finds injection, broken auth, IDOR, missing input validation, hardcoded secrets, insecure storage, and OWASP Top 10 issues in KAMOS code. Use when performing security audits, looking for vulnerabilities, or auditing authentication and authorization. Triggers: security review, audit, OWASP, vulnerability, auth review, IDOR, injection."
---

# Security Review Skill

Adversarial review targeting the OWASP Top 10 and common implementation flaws. Read code as an attacker — what's the path to unauthorized data access, account takeover, or privilege escalation?

## Method — per endpoint

For every HTTP endpoint, trace request → response and verify in order:

1. **Auth** — is the route behind `middleware.Auth` or explicitly public?
2. **Authorization** — for user-scoped resources, is ownership verified against the authenticated user (defense against IDOR)?
3. **Input validation** — are path params, query params, body fields validated for type, length, format?
4. **Output** — does the response leak internal fields, stack traces, or other users' data?
5. **Privacy** — for content from private profiles (`SPEC §5.1`), is access gated to approved followers?

## High-value greps

```bash
# SQL injection candidates (string formatting near SQL)
grep -rn "fmt\.Sprintf.*\(SELECT\|INSERT\|UPDATE\|DELETE\|WHERE\)" backend/

# Hardcoded secrets
grep -rn "password\s*=\s*\"[^\"]\|secret\s*=\s*\"[^\"]\|api_key\s*=\s*\"[^\"]\|jwt_secret\s*=\s*\"" .

# JWT algorithm confusion / unsafe parsing
grep -rn "alg.*none\|ParseUnverified\|SkipClaimsValidation" backend/

# Insecure Flutter storage of credentials
grep -rn "SharedPreferences" frontend/lib/ | grep -i "token\|jwt\|auth\|password"

# Missing auth middleware on chi routes
grep -rn "r\.\(Get\|Post\|Put\|Patch\|Delete\)" backend/ | grep -v "auth\|public"

# Skipped errors on security-sensitive ops
grep -rn "_\s*=\s*.*\(auth\|token\|verify\|decode\|sign\)" backend/

# OS command execution
grep -rn "exec\.Command\|os/exec" backend/

# Logging credentials
grep -rn "log\.\|slog\.\|fmt\.Print" backend/ | grep -i "password\|token\|secret"
```

## OWASP Top 10 — KAMOS coverage

| # | Category | Check |
|---|---|---|
| A01 | Broken Access Control | Every PATCH/DELETE on user-owned resource checks `claims.UserID == resource.OwnerID`; private profile content gated to approved followers; admin-only endpoints require explicit role check |
| A02 | Cryptographic Failures | Passwords with bcrypt (cost ≥ 10) or argon2id; JWT secret from env (not hardcoded); HTTPS enforced (CORS + production config) |
| A03 | Injection | All `pgx` parameters bound; no `fmt.Sprintf` near SQL; no `os/exec` with user input; no `template.HTML` for user content |
| A04 | Insecure Design | Auth endpoints rate-limited; account enumeration not possible (same response for "user not found" vs. "wrong password") |
| A05 | Security Misconfiguration | No debug endpoints in production; CORS allowlist not `*`; `pprof` not exposed publicly |
| A06 | Vulnerable / Outdated Components | No `crypto/md5` or `crypto/sha1` for passwords or tokens; no obviously deprecated auth libs |
| A07 | Auth & Session Failures | JWT expiry enforced; refresh token rotation if implemented; logout invalidates token (denylist or short TTL) |
| A08 | Software & Data Integrity | Email verification token has expiry and single-use enforcement (`SPEC §3.1`: 24h, marked `used_at`) |
| A09 | Security Logging | Auth failures logged with user identifier (not password); PII not logged |
| A10 | SSRF | Any URL fetched from user input goes through an allowlist; image URL fields are not fetched server-side without validation |

## KAMOS-specific attack surface

- `POST /checkins`: must verify the authenticated user owns the check-in on PATCH and DELETE
- `GET /users/:username` and `GET /users/:username/checkins`: must hide content if target is private and viewer is not an approved follower; same response shape (404) for "doesn't exist" vs "private and you can't see it" to prevent enumeration
- `POST /auth/google`: must verify `aud` claim in the Google ID token matches the configured `GOOGLE_CLIENT_ID`; reject expired tokens; reject non-`RS256` algs
- `POST /auth/email/register`: rate-limit to prevent email bombing; verification token expires in 24h (`SPEC §3.1`)
- `PATCH /users/me`: ensure only the authenticated user can modify their own profile; reject any field not in the allowlist (no `is_admin` smuggling)
- JWT secret: from env, never hardcoded; algorithm explicitly `HS256` or `RS256`, never `none`
- Flutter: JWT in `flutter_secure_storage`, never `SharedPreferences` (`SPEC §3.1` security policy)
- PostgreSQL: no raw string interpolation in any runtime-built query

## Severity guide

| Severity | Meaning |
|---|---|
| CRITICAL | Direct data breach or account takeover possible without auth, or SPEC-mandated security control absent (e.g., JWT in SharedPreferences) |
| HIGH | Requires auth but enables access/modification of other users' data |
| MEDIUM | Leaks internal info; exploitable under specific conditions |
| LOW | Defense-in-depth gap with no direct exploit path |

## Output format

Write to `_workspace/review/security_findings.md` with `[SEC-NNN]` numbering. Always include an attack scenario — abstract findings without exploitation context can't be triaged.

```markdown
## [SEC-NNN] Short title
- Severity: CRITICAL | HIGH | MEDIUM | LOW
- OWASP Category: e.g., A01 Broken Access Control
- Location: file:line
- Finding: the vulnerability
- Attack scenario: how an attacker exploits it (concrete steps)
- Fix: specific code change
```

## Cross-domain SendMessage

- If a finding has architectural roots (e.g., auth logic duplicated and one branch is missing the check) → SendMessage `arch-reviewer`
- If a fix would have perf cost (e.g., per-request ownership DB check) → SendMessage `perf-reviewer` to coordinate on an efficient fix
- Receive incoming SendMessage from other reviewers about likely security-affected locations

## Uncertainty

CRITICAL findings go in the report even when uncertain — flag as "Needs verification" rather than omit. Auth flows that are hard to fully trace get marked "auth flow unverified" so the consolidated report can flag them.
