# Spawn prompt — security-reviewer (code-review)

```
subagent_type: security-reviewer
model: <recommended_model from security-review SKILL.md>
prompt:
Read docs/history/review/00_scope.md. Use the security-review skill.

Write findings to docs/history/review/security_findings.md per the skill's
output format. SEC-NNN numbering, severity in {CRITICAL, HIGH, MEDIUM,
LOW} per the review-fanout protocol's severity normalization.

Catalog invariants to verify (cite IDs in findings; do not restate):
- [[invariant:jwt-storage]] — flutter_secure_storage only; iOS Keychain
  first_unlock_this_device
- [[invariant:admin-auth]] — HttpOnly + CSRF double-submit; no Bearer in
  admin; /v1/admin/me is the cookie-authable identity endpoint
- [[invariant:sanitize-text]] — every free-text field
- [[invariant:soft-delete]] — auth cache rejects soft-deleted users

A violation of any of the above is automatically CRITICAL, not HIGH.

Cross-domain SendMessages per [[protocol:review-fanout]]:
- [[protocol:REVIEW-003]] if a vulnerability has a structural root cause
- [[protocol:REVIEW-004]] if a fix has perf cost
- Receive [[protocol:REVIEW-001]] / [[protocol:REVIEW-006]] /
  [[protocol:REVIEW-008]] from other reviewers; cross-reference

TaskUpdate per [[protocol:REVIEW-010]] on completion.
```
