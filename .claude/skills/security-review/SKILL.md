---
name: security-review
description: "Security vulnerability review skill. Finds injection, broken auth, IDOR, missing validation, hardcoded secrets, and OWASP Top 10 issues. Use when performing security audits, looking for vulnerabilities, or checking authentication and authorization code."
---

# Security Review Skill

Adversarial code review targeting OWASP Top 10 and common implementation flaws.

## High-Value Grep Patterns

Run these searches first to quickly surface candidates:

```bash
# SQL injection candidates
grep -rn "fmt.Sprintf.*SELECT\|fmt.Sprintf.*INSERT\|fmt.Sprintf.*WHERE" .

# Hardcoded secrets
grep -rn "password\s*=\s*\"[^\"]\|secret\s*=\s*\"[^\"]\|api_key\s*=\s*\"[^\"" .

# Skipped errors on security-sensitive ops
grep -rn "_ = .*auth\|_ = .*token\|_ = .*verify" .

# Missing auth middleware (Go chi routes without middleware)
grep -rn "r\.Get\|r\.Post\|r\.Put\|r\.Delete" . | grep -v "Use("

# Flutter: insecure storage
grep -rn "SharedPreferences.*token\|prefs.*jwt\|prefs.*auth" .

# JWT algorithm confusion
grep -rn "alg.*none\|ParseUnverified\|SkipClaimsValidation" .
```

## Per-Endpoint Security Trace

For each HTTP endpoint, verify in order:
1. **Auth**: is the route behind the auth middleware or explicitly public?
2. **Authorization**: if resource is user-scoped, is ownership verified against the authenticated user ID?
3. **Input validation**: are path params, query params, and body fields validated (type, length, format)?
4. **Output**: does the response leak internal fields, stack traces, or other users' data?

## OWASP Top 10 Checklist

| # | Category | Check |
|---|----------|-------|
| A01 | Broken Access Control | All write routes check resource ownership; no IDOR on GET routes |
| A02 | Cryptographic Failures | Passwords hashed with bcrypt/argon2; JWT uses strong secret; HTTPS enforced |
| A03 | Injection | All DB parameters bound; no string-formatted SQL; no `exec` with user input |
| A04 | Insecure Design | Auth endpoints rate-limited; account enumeration not possible via error messages |
| A05 | Security Misconfiguration | No debug endpoints in production; CORS restricted to known origins |
| A06 | Vulnerable Components | No obviously deprecated auth patterns (`MD5`, `SHA1` for passwords) |
| A07 | Auth & Session Failures | JWT expiry enforced; refresh token rotation; logout invalidates token |
| A09 | Security Logging Failures | Auth failures logged; PII not logged |
| A10 | SSRF | Any URL fetched from user input goes through an allowlist |

## Severity Guide

| Severity | Meaning |
|----------|---------|
| CRITICAL | Direct data breach or account takeover possible without auth |
| HIGH | Requires auth but can access/modify other users' data |
| MEDIUM | Leaks internal info; exploitable under specific conditions |
| LOW | Defense-in-depth gap; no direct exploit path |

## Output

Write to `_workspace/review/security_findings.md` with `[SEC-NNN]` numbering. Always include an attack scenario — abstract findings without exploitation context are hard to prioritize.
