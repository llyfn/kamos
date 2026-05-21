# QA Report — Phase 6 Flutter (in-flight, per-layer; backend slice 3c9f87f landed during run)

Date: 2026-05-16
Scope: Phase 6 Flutter slice — four commits.
- `f9d3db6` collection visibility toggle (`Collection.visibility` enum + edit screen + repository PATCH)
- `042688d` public collections discovery tab (`lib/features/discover/`)
- `52c7d7b` comments on check-ins (`lib/features/comments/`, `Comment` model, `CheckInDetailScreen`, composer + tile + section)
- `c752d05` comment count badge on feed cards (`FeedItem.commentCount` + badge + nav)

Verdict: **PASS WITH MINOR**

`flutter analyze` → "No issues found! (ran in 2.1s)". 86/86 PASS across the full suite (12 new tests for Phase 6 + 74 unchanged).

Backend Phase 6a (`3c9f87f`, `94ee270`, `3e7cf43`) has now landed and `openapi.yaml` is the authoritative contract — the drift findings below are graded against the OpenAPI spec as it stands at QA time.

---

## Lens 1 — Integration boundaries

- **`Collection.visibility` ↔ OpenAPI**: PASS. OpenAPI (`openapi.yaml:2074-2081`) declares `visibility: { type: string, enum: [private, public], default: private }` and adds it to `Collection.required`. Dart `Collection` (`lib/core/models/collection.dart:31`) defaults to `CollectionVisibility.private` via `@Default`. `CollectionVisibilityParse.fromWire` accepts `"public"` and falls back to `private` for any other value (including missing) — backward-compatible with older servers that never emit the field. Tests `collection_visibility_repository_test.dart:53-78` cover all three cases (missing / public / unknown string).
- **`PATCH /v1/collections/{id}` body shape**: PASS. OpenAPI `UpdateCollectionRequest` (`openapi.yaml:2106-2117`) allows `{name?, visibility?}` and 422s on `{}`. Dart `CollectionRepository.updateVisibility` (`lib/features/collections/repository/collection_repository.dart:34-43`) sends `{visibility: <wire>}` alone — exactly one field, no `name` — server accepts. Round-tripped by `collection_visibility_repository_test.dart:82-114`.
- **`POST /v1/check-ins/{id}/comments` body shape**: PASS. OpenAPI `openapi.yaml:619-627` requires `{body}` with `1..500` chars; server rejects C0 control bytes (except `\t` / `\n`) with 422 (`openapi.yaml:617-618`). Dart `CommentRepository.create` (`lib/features/comments/repository/comment_repository.dart:36-48`) sends `{body}` and pre-rejects `>500` chars client-side with `CommentTooLongException`. **No client-side control-char filter** — relies on server-side 422, which surfaces in the UI as the generic `commentsPostFailed` SnackBar. The beverage_request feature filters control chars client-side; comments do not. Inconsistency — see MINOR #4.
- **`DELETE /v1/comments/{id}` ownership / status mapping**: PASS. OpenAPI returns 204 on success, 403 if the caller is not the author and lacks moderator/admin role, 404 if already soft-deleted. Dart `CommentRepository.deleteOwn` (`lib/features/comments/repository/comment_repository.dart:50-71`) maps 403 → `CommentForbiddenException`, 404 or `code == 'COMMENT_DELETED'` → `CommentDeletedException`, rethrows otherwise. Tests `comment_repository_test.dart:135-167` cover both 403 and 404.
- **`GET /v1/check-ins/{id}/comments` response envelope**: **DRIFT — MINOR/MAJOR**. OpenAPI (`openapi.yaml:610`) declares `PageOfComment` — a cursor-paginated envelope (`{items, next_cursor, has_more}`) most-recent-first. Backend repository confirms `ORDER BY c.created_at DESC, c.id DESC` (`internal/repository/comments.go:104`). Dart `CommentRepository.list` (`lib/features/comments/repository/comment_repository.dart:25-34`):
  1. Does **NOT** pass a `cursor` query — fetches only the first page (max 20 by default). For check-ins with >20 comments, older comments are silently truncated. **MAJOR** — see findings.
  2. Returns `List<Comment>` (drops `next_cursor` / `has_more`).
  3. Accepts BOTH `{items: [...]}` envelope AND a bare top-level array — the bare-array branch is dead code against the real server but is exercised by `comment_repository_test.dart:80-96`.
  4. The `commentsProvider` doc-comment says "flat list, oldest first per server contract" (`comment_providers.dart:31`), but the server returns DESC (newest first). The optimistic post appends to the end (`comment_providers.dart:35`) — so new comments visually appear at the BOTTOM, but the server returns them at the TOP on next refresh. **MAJOR** — UX bug.
- **`POST /v1/check-ins/{id}/comments` response status**: OpenAPI returns `201`. Dart `Dio` default `validateStatus` is 200–299 — 201 passes through. PASS.
- **`Comment.user` shape**: PASS. OpenAPI `Comment.user: CheckinUser` (`openapi.yaml:2029`), and `CheckinUser` is the slim public-profile shape — email / email_verified are NEVER on the wire (`openapi.yaml:2024`). Dart `Comment` (`lib/core/models/comment.dart:23`) reuses `CheckinUser` — same model used by `Checkin` and `FeedItem`. **SPEC privacy invariant intact**.
- **`PublicCollectionOwner` ↔ Dart `CollectionOwner`**: **DRIFT — MINOR**. OpenAPI (`openapi.yaml:2085-2096`) requires `[id, username, display_username, display_name]` plus optional `avatar_url`. Dart `CollectionOwner` (`lib/core/models/collection.dart:50-66`) has `[id, username, displayUsername, avatarUrl?]` — **missing `display_name`** entirely. No UI consumer reads `displayName` today (the discover screen only renders `owner.displayUsername` at `public_collections_screen.dart:153`), so the runtime is unaffected — but the model lies about the wire shape. Tests don't catch this because the stub fixtures also omit `display_name`. See MINOR #1.
- **`FeedItem.comment_count`**: PASS. OpenAPI declares `comment_count: { type: integer, default: 0 }` and the comment near `openapi.yaml:2009-2012` explicitly notes it is NOT in `required` for backward compat. Dart `FeedItem.commentCount` defaults to `0` via `@Default` and `fromJson` reads `(json['comment_count'] as int?) ?? 0` (`lib/core/models/checkin.dart:115, 138`). Round-trip covered by `check_in_card_comment_badge_test.dart:104-123`.
- **ARB parity**: PASS. en/ja/ko each carry **202** translatable keys (verified via direct count, not the commit-stat sum). Zero asymmetry. New Phase 6 keys: `collectionVisibilityPublicTitle/PublicSubtitle/PrivateSubtitle`, `publicCollectionsTitle/Empty/ByOwner/DiscoverCta`, `commentsTitle/Empty/ComposerHint/Submit/Delete/DeleteConfirm/CharCount/TooLong/PostFailed/LoadFailed`, `feedCardCommentsCountLabel`, plus the `@`-metadata placeholders for the parameterized strings. The commit description claimed "+21 keys → 211/211/211" — the actual count is 202; the +21 number is wrong, but **parity is what matters and parity is clean**. The discrepancy is just a commit-message arithmetic error.
- **go_router**: PASS. Two new routes registered:
  - `/discover/public-collections` at `lib/app/router.dart:109-112` → `PublicCollectionsScreen`. Reachable from `collections_list_screen.dart:62-92` (a featured row at the top of the collections tab).
  - `/check-ins/:id` at `lib/app/router.dart:127-131` → `CheckInDetailScreen`. Reachable from the feed card body (`check_in_card.dart:44 onTap: () => context.push('/check-ins/${item.id}')`) AND the comment-count badge (`check_in_card.dart:207`). The whole card already routes there — the badge is a redundant tap target but supplies the count + a dedicated Semantics label.
- **Category / rating / cursor / secure-storage SPEC invariants**: PASS. No category-string surface touched. Rating widget unaffected. Cursor pagination on the new `/v1/collections/public` list — both the repository (`public_collections_repository.dart:23-26`) and the notifier (`public_collections_providers.dart:63-83`) thread `cursor` correctly. Secure-storage discipline preserved — no new JWT touches.

## Lens 2 — Architecture

- **Comments feature follows venues exception-extract convention**: PASS. `lib/features/comments/exceptions.dart` exists as a leaf file (matches `lib/features/venues/exceptions.dart` and `lib/features/beverage_requests/exceptions.dart`). Three typed exceptions: `CommentForbiddenException`, `CommentDeletedException`, `CommentTooLongException`. Repository throws them; widgets pattern-match on `CommentTooLongException` for a specific toast and fall through to a generic toast for everything else.
- **No widget-imports-Dio**: PASS. Spot-checked all five new widget files (`comment_composer.dart`, `comment_tile.dart`, `comments_section.dart`, `public_collections_screen.dart`, `collection_detail_screen.dart`). None import `package:dio`. Repositories are the only Dio touch-points.
- **`CommentsSection` is decoupled / embeddable**: PASS. Takes only `checkInId` as a constructor arg (`comments_section.dart:19`). All state is owned by the providers it reads. The `CheckInDetailScreen` embeds it inside a `ListView`. Could be dropped into a future "comments preview" surface (e.g., bottom-sheet from a feed card long-press) without modification.
- **Cursor pagination on `/v1/collections/public`**: PASS. `PublicCollectionsNotifier.loadMore` (`public_collections_providers.dart:63`) correctly threads `nextCursor`, guards re-entrancy with `isLoadingMore`, and stops on `hasMore == false`. The screen wires it via a scroll listener with a 240-pixel pre-fetch margin (`public_collections_screen.dart:48`). On `loadMore` failure the state is reverted without a toast — defer-to-pull-to-refresh strategy (`public_collections_providers.dart:79-83`).
- **Optimistic delete rollback**: PASS. `CommentsNotifier.deleteOwn` (`comment_providers.dart:42-57`) captures the removed entry + its index, applies the optimistic mutation, awaits the repository, and on any exception re-inserts the entry at its original index. Rethrows so the UI's `_delete` SnackBar fires.
- **Optimistic post rollback**: **MINOR — not symmetrical**. The optimistic post (`comment_providers.dart:31-37`) does NOT pre-append a tentative comment; it awaits the repository, then appends the server-returned comment. This is "pessimistic" — the UI shows a spinner via the composer's `_submitting` flag while the request is in flight, and only inserts the comment on 201. Semantically fine, but the doc-comment block at the top of the file (`comment_providers.dart:1-5`) advertises "optimistic post" — the implementation isn't actually optimistic. Either tighten the doc-comment or make the post truly optimistic. See MINOR #5.
- **No premature abstraction**: PASS. No `CommentService` interface; concrete `CommentRepository`. Same pattern as venues / beverage_requests.

## Lens 3 — Coding conventions

- **Naming**: PASS. Consistent with venues / beverage_requests. `Comment`, `CommentRepository`, `commentRepositoryProvider`, `CommentsNotifier`, `commentsProvider`, `CommentsSection`, `CommentTile`, `CommentComposer`, `CommentForbiddenException`. `CollectionWithOwner` + `CollectionOwner` mirror the OpenAPI schema names.
- **Error handling**: PASS for typed exceptions, no `catch (_) {}` of un-rethrown errors. Two `catch (_)` blocks exist but both immediately rethrow or restore state and rethrow (`comment_providers.dart:51-56`, `public_collections_providers.dart:79-83`). The composer's `_submit` (`comment_composer.dart:48-58`) does NOT explicitly handle exceptions — the calling section handles them and returns `false`. Clean separation.
- **Magic numbers**: PASS. `commentMaxChars = 500` is a top-level file-private const in `comment_composer.dart:13` AND repeated as a literal `500` in `comment_repository.dart:40`. The repository duplicates the constant rather than importing it from the composer file. Acceptable since the composer is widget-layer and the repo is data-layer (different cohesion concerns), but consider hoisting to a shared `core/constants/comments.dart` or to `Comment` itself. See MINOR #6.
- **ARB placeholders correctly typed**: PASS. `commentsCharCount({count}, {max})` uses two `int` placeholders, `feedCardCommentsCountLabel({count})` uses one, `publicCollectionsByOwner({username})` uses a `String`. Verified by inspection of the `@`-blocks in `intl_en.arb`.
- **Test coverage maps to behaviors**: PASS.
  - Comment model: 3 cases (full shape, missing fields → defaults, `deleted_at` preserved).
  - Comment repository: 5 cases (envelope, bare array, create body, >500 throws without request, 403/404 mapping).
  - Comment composer widget: 3 cases (disabled on empty, calls onSubmit + clears, char-counter renders).
  - Comment tile widget: 2 cases (delete affordance shown for own, hidden for others — includes the confirm-dialog path).
  - Collection visibility: 5 cases (default missing, public, unknown fallback, PATCH public body, PATCH private body).
  - Public collections screen: 3 cases (rows render, empty state, error retry).
  - Feed card comment badge: 4 cases (count renders, tap navigates, fromJson default 0, fromJson value 12).
  - **Total: 25 new tests across 8 files. All passing.**

## Lens 4 — Performance / security spot-checks

- **Comment body 500-char cap**: PASS at the composer (`comment_composer.dart:74 maxLength: 500` + `LengthLimitingTextInputFormatter`). Repository re-checks before sending (`comment_repository.dart:40-42`). Backend enforces `1..500` again. Three-layer defense.
- **Comment control-char filter**: NOT ENFORCED CLIENT-SIDE. The composer lets the user type any C0 control byte (other than the OS-restricted ones); the server's 422 surfaces as the generic `commentsPostFailed` toast with no specific guidance. The beverage_request feature explicitly rejects `\x00-\x1F\x7F` via inline regex. Comments do not. **MINOR #4** — add the same regex filter or surface a dedicated localized error on 422 `code == 'INVALID_BODY'`.
- **Visibility toggle ownership gating — IMPORTANT FINDING**: **MAJOR**. The `_VisibilityToggle` widget at `collection_detail_screen.dart:203-243` has a doc-comment claiming:
  > "The current `/collections` tab only lists collections owned by the signed-in user, so reaching this screen implies ownership; the toggle is unconditionally rendered."
  
  This assumption no longer holds in Phase 6. The new `PublicCollectionsScreen` (`public_collections_screen.dart:102`) routes to `/collections/${c.id}` for ANY public collection — including ones the signed-in user does not own. The detail screen renders the toggle unconditionally; a non-owner viewing a public collection sees the "Public collection" SwitchListTile rendered in its current state. If they flip it, the PATCH server-side 403s (handler ownership check), the `catch` clause at `collection_detail_screen.dart:259-262` reverts the local switch state, and no toast is shown — silent failure. **The owner's actual setting is never modified server-side**, so this is a UX bug, not a security bug — but it IS a reachability violation of the doc-comment's stated invariant.
  
  Fix: read `meProvider` in the detail screen, compare against the collection's owner (which is NOT on the wire today for `GET /v1/collections/{id}` — the endpoint returns `Collection` without `owner`, so the client has no direct ownership signal). Two options:
  1. Cheap fix: hide the toggle when arriving via the discover route. Tag the route or pass an extra flag.
  2. Proper fix: add `owner_id` (or just `is_own: bool`) to the `Collection` schema on `GET /v1/collections/{id}`. Server-side cross-check is the source of truth.
  
  **The visibility-toggle-only-on-own-collection check is NOT robust — it relies on reachability alone, and the reachability assumption is now violated by the new discover screen the same agent shipped in the previous commit.**
- **Rate-limit (429) signal**: NOT SPECIALIZED. The `commentsSection._submit` catches any non-`CommentTooLongException` and shows `commentsPostFailed` ("Could not post. Try again."). On a 429 the user sees the same toast as for a 500 / network error. Acceptable for MVP, but a dedicated `commentsRateLimited` ARB key + a 429 branch in `CommentRepository.create` (similar to `deleteOwn`) would improve UX. **MINOR #7**.
- **Soft-deleted comments**: PASS. Backend filters server-side (`comments.go:100 WHERE c.deleted_at IS NULL` per the integration test). Dart `Comment.deletedAt` is exposed but never read in the rendering path. The tile / section never branches on it. The comment file's doc-comment explicitly notes: "the server already filters soft-deleted comments out of the list response — clients never need to render a tombstone" (`comment.dart:9-11`).
- **Feed card badge tap with `commentCount == 0`**: PASS. The badge always renders (no `if (count > 0)` gate at `check_in_card.dart:203`), is always tappable (`onTap: () => context.push('/check-ins/${item.id}')`), and the destination handles the empty-list case via `CommentsSection`'s `data: (comments) { if (comments.isEmpty) return EmptyView(...); }` (`comments_section.dart:50-56`). Verified by `check_in_card_comment_badge_test.dart:74-83` (count=7) but the test does NOT cover the `count=0` rendering or tap path. **MINOR test gap** — add a `commentCount: 0` case asserting `find.text('0')` + tappability.
- **No JWT / secret leak**: PASS. Comment exceptions don't carry the `DioException`'s headers. The optimistic-update rollback paths don't log the request body anywhere.
- **Rebuild scope**: PASS. `CommentComposer` calls `setState` on every text change (`comment_composer.dart:34-36`) — drives the FilledButton enabled state + the live char counter color. Acceptable for a single-field composer, same trade-off the beverage_request screen documented.
- **`PublicCollectionsScreen` scroll listener**: PASS. Listener is added in `initState` and removed in `dispose` (`public_collections_screen.dart:34-43`). `loadMore` is guarded by `isLoadingMore` (`public_collections_providers.dart:66`). No leak, no double-fire.

---

## BLOCKERs

None.

## MAJORs

1. **Comment list is single-page and ordering-flipped against the server contract.** `CommentRepository.list` (`lib/features/comments/repository/comment_repository.dart:25-34`) ignores the cursor envelope entirely — drops `next_cursor` / `has_more`, never requests page 2. For any check-in with >20 comments, older comments are silently truncated. The provider doc-comment (`comment_providers.dart:30-31`) claims the server returns "flat list, oldest first" and the optimistic post appends to the end, but the server actually returns DESC (newest first, confirmed at `internal/repository/comments.go:104`). Two visible effects: (a) the order in the UI is wrong on first render — newest are first, but new posts go to the end, which is inconsistent; (b) on next refresh the new post jumps to the top.

   Fix:
   - Switch `list()` to return `Page<Comment>`, thread `cursor` through a `loadMore` on the notifier, and reverse the optimistic-post insertion to `[created, ...current]` (or restructure the section to render in DESC order with `loadMore` at the bottom).
   - At minimum, fix the ordering: change the optimistic post to prepend, and document that this is a first-page-only view until cursor support lands.

2. **Visibility toggle leaks onto non-owner detail views.** `CollectionDetailScreen` unconditionally renders `_VisibilityToggle` (`collection_detail_screen.dart:144`). The widget's doc-comment claims reachability gates ownership, but the new public-collections discovery screen routes to the same detail path for ANY public collection, including ones the signed-in user does not own. The server-side 403 on a non-owner's PATCH prevents data corruption, but the UI shows a toggleable switch to non-owners with silent rollback on failure (the `catch (_)` at `collection_detail_screen.dart:259-262` doesn't show a toast). UX bug + the documented invariant in the widget's doc-comment is no longer true.

   Fix (preferred): add `is_own: bool` (or `owner_id`) to the `Collection` schema returned by `GET /v1/collections/{id}` and gate the toggle on it. This is a backend change. Coordinate with backend-engineer.
   
   Fix (quick): hide the toggle when the detail screen is reached via the discover route — pass an extra `viewerIsOwner: false` and only render the toggle when `meProvider.value?.user.id == collection.ownerId`. But that requires `owner_id` on the wire too, so the proper fix is unavoidable.

## MINORs

1. **`CollectionOwner` model is missing `display_name`.** OpenAPI's `PublicCollectionOwner` requires `[id, username, display_username, display_name]`; the Dart model has `[id, username, displayUsername, avatarUrl?]`. No UI consumer reads `displayName` today, so runtime is unaffected, but the model lies about the wire shape and tests don't catch it. Add the field. (`lib/core/models/collection.dart:50-66`)

2. **`commentsProvider` doc-comment overstates "optimistic post".** The implementation awaits the repository before mutating the list — that's pessimistic, not optimistic. Either tighten the doc-comment or make it truly optimistic with a temporary client-side id + rollback on failure. (`lib/features/comments/providers/comment_providers.dart:1-5, 31-37`)

3. **`comment_repository_test.dart:80-96` exercises a code path that the real server never produces.** The bare-array response branch in `CommentRepository.list` (`comment_repository.dart:30`) is dead against the OpenAPI contract (`PageOfComment` always wraps `items`). Either drop the bare-array branch and the test, or document why it exists (legacy contract? in-flight backend?).

4. **No client-side control-char filter on the comment composer.** The server rejects C0 control bytes (except `\t` / `\n`) with 422 (`openapi.yaml:617-618`); the composer accepts them and surfaces the failure as the generic `commentsPostFailed` toast. The `beverage_request` feature filters control chars with an inline regex; comments should match for consistency. (`lib/features/comments/widgets/comment_composer.dart`)

5. **`commentMaxChars = 500` is duplicated in the composer and repository.** The composer declares the constant; the repository hard-codes the literal. Hoist to a shared location (e.g., `core/constants/comments.dart` or as a static on `Comment`). (`comment_composer.dart:13`, `comment_repository.dart:40`)

6. **No dedicated 429 handling on comment create.** The post fails over to the generic `commentsPostFailed` toast on any non-`CommentTooLongException`. A 429 from the rate-limited `POST` (`openapi.yaml:615-616`: "3 rps / burst 6") deserves its own ARB key + message. (`lib/features/comments/widgets/comments_section.dart:92-99`)

7. **Test gap — `commentCount == 0` rendering / tap.** `check_in_card_comment_badge_test.dart` only covers `count=7` (render) and `count=2` (tap). Add a `count=0` case to lock in that the badge always renders and is always tappable. (`test/check_in_card_comment_badge_test.dart`)

8. **Commit-message arithmetic error on Phase 6 commits.** The agent's claim of "+21 keys → 211/211/211" is wrong; the actual ARB key count is 202/202/202 (parity intact, count off). Cosmetic — flagging for future commit-message hygiene.

9. **`_VisibilityToggle._isPublic` shadows the provider source of truth.** The widget keeps a local `late bool _isPublic = widget.collection.visibility == CollectionVisibility.public` and only refreshes via `ref.invalidate`. If the collection is mutated by another path (e.g., a future bulk-action screen) while the detail screen is mounted, the local state would diverge. Defer — single-screen mutation surface for MVP. (`collection_detail_screen.dart:215-216`)

## Backlog (cosmetic, defer)

- `comments_section.dart:46` — `error: (_, _) =>` uses `_` twice as the error + stack-trace parameter names. Dart 3 allows it but a single named `(err, _)` reads clearer.
- `comment_repository.dart:75` — `commentRepositoryProvider` returns a fresh `CommentRepository` on each read. Since `_dio` is stable, this is fine, but mark `Provider` instead of letting it be re-read more than needed.
- `public_collections_providers.dart:79-83` — loadMore failure silently swallows. Consider an `onError` Riverpod listener for telemetry without re-rendering.
- `collection_detail_screen.dart:131` — the existing "`${collection.entryCount} · ${l.collectionsPrivate}`" subtitle hard-codes `Private` even when `collection.visibility == public`. Pre-Phase-6 dead text; not in this commit's diff but adjacent.

## Test counts

- New: 25 tests across 8 files
  - `collection_visibility_repository_test.dart` — 5 tests
  - `comment_model_test.dart` — 3 tests
  - `comment_repository_test.dart` — 5 tests
  - `comment_composer_test.dart` — 3 tests
  - `comment_tile_test.dart` — 2 tests
  - `public_collections_repository_test.dart` — (verified by suite; not deep-read here)
  - `public_collections_screen_test.dart` — 3 tests
  - `check_in_card_comment_badge_test.dart` — 4 tests
- Full suite after this slice: 86 tests, all passing
- `flutter analyze`: clean

---

**Net:** ship-able with one OpenAPI-driven follow-up to fix the comment list cursor/order drift (MAJOR #1) and one cross-feature reachability gap on the visibility toggle (MAJOR #2). Both are surgical fixes — the second is the more interesting one because it surfaces a doc-comment invariant that became false when the public-collections screen was added in the same multi-commit slice. The visibility-toggle ownership check is **NOT robust** today: it relies entirely on reachability, and reachability changed under it. Recommend a backend coordination loop to add `is_own` or `owner_id` to the `Collection` GET response before promoting Phase 6 to a release branch.
