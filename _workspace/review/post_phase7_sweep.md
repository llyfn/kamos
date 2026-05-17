# Post-Phase-7 Cumulative MINOR Sweep + Roadmap Close-Out

Date: 2026-05-17
Pattern: `feedback_post_phase_minor_sweep.md`

Phase 7 is the **last phase** of the post-MVP roadmap (`~/.claude/plans/mutable-juggling-cook.md`). This sweep is the final post-phase pass.

## Commits applied (2 in this sweep)

| # | Commit | Layer | Closes |
|---|---|---|---|
| 1 | `19e360e` | backend | MINOR-2 (`localeKey` whitelist en/ja/ko, unsupported → "en" → cache axis bounded to 3 buckets), MINOR-3 (named sizing constants in `caches.go`) |
| 2 | `e996029` | flutter | MINOR-2 Flutter (`kBypassCache` wired to feed's `RefreshIndicator.onRefresh` via `forceRefresh: true` on `FeedRepository.getFeed`) |

## Test counts after sweep

| Suite | Phase 6 close | Phase 7 final | Sweep delta | **Total** |
|---|---|---|---|---|
| Backend unit | 125 | 145 | +1 (`TestLocaleKey` × 15 subtests) | **146** |
| Backend integration | 96 | 102 | 0 | **102** |
| Flutter | 99 | 107 | +2 (force-refresh repo) | **109** |
| Admin client (Vitest) | 11 | 11 | 0 | **11** |
| **Total** | 331 | 365 | +3 | **368** |

`go build ./...`, `flutter analyze`, `tsc --noEmit`, `vite build` — all clean.
ARB parity: **206/206/206**.

## Items DEFERRED (judgment calls — backlog only since no more phases)

| Source | Item | Reason |
|---|---|---|
| Phase 7 backend QA MINOR-1 | ETag truncated SHA-256 (8 bytes / 16 hex) | Deliberate trade-off documented in `etag.go:50-55`; ~2^32 collision domain is negligible at our scale. |
| Phase 7 backend QA MINOR-4 | `invalidateBeverageDetail` no-op on idempotent retry | Documented at the call site; no real-world failure mode (idempotent retries with different actor are extraordinarily rare). |
| Phase 7 Flutter QA MINOR-4 | `maxStale: 7 days` request-side | Currently fine because the LRU + write-path invalidation keeps drift bounded; a future Phase 1 metric could prove a tighter cap is needed. Wait for data. |
| Phase 7 Flutter QA MINOR-5 | `MemCacheStore` is byte-bounded only, not entry-bounded | Theoretical concern at MVP scale; flagged for completeness. |
| Phase 6 backend MINOR-2 | Hard-delete sweep job doesn't handle comments on user purge | Phase 7+ concern in the original plan; with no more phases, this becomes a real backlog item — needs to be picked up before a real user purge happens in production. |
| Phase 4 carry-overs (`feedCardAtVenue` country, `VenueSearchQuery` cosmetic, etc.) | Various cosmetic items | Documented across multiple sweeps; would only materialize if specific UX gaps are reported. |

## SPEC invariants — still 12/12 PASS

No invariant touched.

---

## 🎉 Post-MVP roadmap status — COMPLETE

| Phase | Status | Date | Headline |
|---|---|---|---|
| 0 — Cleanup & Foundations | ✅ done | 2026-05-14 | QA-deferred MINOR backlog closed |
| 1 — Observability + Rate-limit + Jobs | ✅ done + production-wired | 2026-05-14 | OTel + Sentry + token-bucket + 4 bg jobs |
| 2 — Auth Hardening | ✅ shipped | 2026-05-14 | Rotating refresh tokens + Google OAuth scaffold |
| 3 — Photos + SMTP | ✅ shipped (gated) | 2026-05-14 | R2 presigned uploads + Resend mailer |
| 4 — Venue (Foursquare) | ✅ shipped + hardened | 2026-05-16 | Venue picker + check-in upsert + feed projection |
| 5 — Admin Web Client + RBAC | ✅ shipped | 2026-05-16 | RBAC + admin endpoints + SEC-006 + React+Vite+TanStack admin |
| 6 — Public Collections + Comments | ✅ shipped | 2026-05-17 | Visibility toggle + discovery + flat comments + admin moderation |
| **7 — Caching** | ✅ **shipped** | **2026-05-17** | **In-process LRU + ETag + Cache-Control + cache-hit metric + Flutter Dio cache** |

**Total tests:** 368 across 4 suites.
**SPEC invariants:** 12/12 PASS.
**ARB parity:** 206/206/206.

## What's left owed by the user (cookbook)

| Item | Phase | Effect when supplied |
|---|---|---|
| §C1 Google OAuth client IDs + .plist | 2 | Real Google sign-in flips on |
| §C2 Cloudflare R2 creds | 3 | Real photo upload flips on |
| §C3 Resend API key + verified domain | 3 | Real verification emails flip on |
| §C5 Foursquare API key | 4 | `/v1/venues/search` flips on (upsert already works) |
| §C6 Cloudflare Pages | 5 | Admin client hosting |

All gates are env-flag only — no code changes needed once creds land in `local.env`.

## Roadmap-wide backlog (long-tail, none safety-relevant)

Carried beyond the per-phase sweeps:
- Sentry-for-admin-client SDK wire-up (Phase 5 follow-on)
- `moderation_log` Phase-6 backend MINOR-2: hard-delete sweep needs comment-cleanup pre-purge
- R2 HEAD-verify before promote (Phase 3 hardening)
- `password_reset.*` + `email_change.*` email templates (Phase 5+ when UI lands)
- Phase 7 Flutter MINOR-4/5: tighten cache freshness + add entry-bound to MemCacheStore (driven by metrics)
- Various cosmetic deferred items (see `post_phase5_sweep.md` + `post_phase6_sweep.md`)

## Orchestrator patterns proven during this roadmap

1. **Parallel per-layer QA** — QA fires the moment a layer's agent returns, in parallel with still-running layers. Saved as `feedback_per_layer_qa_in_parallel.md`.
2. **Implementer owns QA-flagged fixes** — MAJOR/BLOCKER findings route back to the implementer agent (SendMessage or fresh-spawn), not the orchestrator. Saved as `feedback_implementer_owns_qa_fixes.md`. Validated across Phases 4-7: every BLOCKER + MAJOR closed without orchestrator context burn.
3. **Post-phase MINOR sweep** — after every phase's final QA returns PASS, sweep cumulative backlog and apply reasonable fixes. Saved as `feedback_post_phase_minor_sweep.md`.
4. **Sentinel-skip for stale findings** — agents correctly skip carry-over items whose premise turned out to be wrong (e.g., Phase 5 `PhotoRef.id` not actually on the wire; Phase 6 backend `commentsViewerID` became live during the BLOCKER fix). No silent invented work.

## Next steps (user-facing)

- Beta-test the admin client + Flutter app on physical devices
- Wire the vendor creds (cookbook §C1-C5)
- Configure Cloudflare Pages for admin hosting (cookbook §C6)
- Add Sentry SDK to admin client when ready
- Monitor Grafana cache-hit-rate panel after some real traffic; tighten TTLs if hit rate is suboptimal
