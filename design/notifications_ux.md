# Notifications & bottom-nav rewrite — design spec

Scope: visual + behavioral decisions for the in-app notifications surface and the 5-tab bottom-nav rewrite, per `SPEC.md` §5.4 (rewritten by orchestrator). No new tokens. All references are to existing tokens in `design/colors_and_type.css` and existing primitives in `design/ui_kits/mobile/components/Primitives.jsx`.

Source of truth: `SPEC.md` §5.3 (Toasts) and §5.4 (Notifications).

---

## 1. Bottom navigation rewrite

The MVP-era 5-tab bar with a raised center "Check in" button is replaced. Check-in is no longer a tab — it moves to a primary CTA inside `Feed` and `Beverage detail` screens (the existing entry points already used in the prototype; Flutter engineer keeps them as-is).

### 1.1 Tab order (left → right)

| Slot | Tab id | Label (en) | Icon (Primitives.jsx) | Route |
|---|---|---|---|---|
| 1 | `feed` | Feed | `home` | `/feed` |
| 2 | `lists` | Lists | `bookmark` | `/collections` |
| 3 | `discover` | Discover | `search` | `/discover` |
| 4 | `notifications` | Notifications | `bell` | `/notifications` |
| 5 | `me` | Me | `user` | `/me` |

Notes:
- **Discover** is the rename of the former Search tab. The screen content is unchanged (`SearchScreen.jsx`); only the tab label, tab id, and route change. SPEC §7 "Beverage Discovery" already groups search + browse-by-category + browse-by-producer under "discovery" — the rename aligns navigation with the spec section title.
- **The Lists tab keeps the pre-existing `/collections` route** rather than renaming to `/lists`. The implementation kept the deeper route name to avoid a folder rename across `lib/features/collections/`; only the user-facing tab label is "Lists". A `/lists` route alias was considered and intentionally not added — no inbound deep links to `/lists` exist.
- **No center FAB.** All five tabs use the same hairline-icon style. The raised Ai-iro circle button is removed from `Shell.jsx::TabBar`.
- Tab order rationale: own surfaces (Feed, Lists) before exploration (Discover) before incoming activity (Notifications) before account (Me). Notifications sits second-from-right so the unread dot reads naturally as "new attention pending" without crowding the user-control tab.

### 1.2 Visual treatment

Existing `TabBar` styling stays: hairline border-top, `rgba(252,250,246,0.92)` page-tinted blurred background, 64px tall, 22px icons, 10px/600 label. Active = `--c-ai`; inactive = `--fg-3`. The previously asymmetric center cell is removed; all five cells are now identical column flex children with `flex: 1`.

### 1.3 Unread dot on the Notifications tab

| Property | Value | Token |
|---|---|---|
| Shape | Circle | — |
| Size | `8px` diameter | spacing literal (no token; matches the 4px base × 2) |
| Position | Top-right corner of the bell icon, `2px` from the icon's top, `4px` to the right of the icon's right edge (so the dot sits just outside the 22px icon glyph, not on top of a stroke) | — |
| Fill color | Koh (warm terracotta) | `--c-koh` |
| Border | `2px solid var(--bg-page)` to keep the dot legible against blurred tab-bar background | `--bg-page` |
| Render condition | `hasUnread === true` (any notification row has `read_at IS NULL`) | — |
| Count | None — dot only, never a number (SPEC §5.4 explicit) | — |
| Animation on appear | None. The dot fades in via the natural component re-render. Reserving motion for kanpai. | — |
| Animation on clear | Crossfade out over `var(--dur-base)` (200ms) — feels less abrupt than a hard remove when "Mark all read" fires. | `--dur-base`, `--ease-out` |

#### Why Koh

Color-distinct from `--c-ai` (the active-tab + brand color). Using `--c-ai` for the dot would make it disappear visually when Notifications is the active tab. Akane (`--c-akane`) is reserved for destructive confirmations only (see `design/README.md` voice rules) — using red for a passive social-attention indicator would feel alarming and break the calm brand voice.

Koh is the warm accent reserved for kanpai/toast moments. The existing `Badge` primitive in `Primitives.jsx::Badge` already uses `--c-koh` for the now-removed bell-icon follow-request badge — so users have already learned "warm dot on a bell glyph = new social activity for you." Moving that semantic from a bell-with-badge inside Feed to a dot-on-a-bell-tab in the bottom nav preserves the learned color meaning while simplifying the nav. No new semantic added; one removed.

(See "Token gaps noticed" at the end for the one minor caveat.)

### 1.4 Migration of the bell-with-badge

The old `FeedScreen.jsx` rendered a bell icon in its top-right corner with a `Badge` showing the pending follow-request count, opening `InboxScreen.jsx`. With the rewrite:

- The bell-in-Feed-header is **removed** entirely.
- The `Inbox` screen is **removed**; the deep link `/inbox` redirects to `/notifications` (server-side / router-side concern — flagged for Flutter and backend).
- Follow requests now appear inline as `follow_request` notification rows with Approve / Decline buttons (see §2 below).
- The `Badge` primitive is **retained** in `Primitives.jsx` for any future numeric-badge use, but is unused by this milestone. The unread-dot is a new lightweight rendering that lives inside `TabBar`, not a `Badge` reuse.

---

## 2. Notifications screen

Single screen at `/notifications`. Rendered at the `notifications` tab slot in the bottom nav.

### 2.1 Page layout

```
┌─────────────────────────────────────┐
│  TopBar (52px)                      │
│  ┌────────────────────────────┐    │
│  │  Notifications      Mark all read │
│  └────────────────────────────┘    │
├─────────────────────────────────────┤
│                                     │
│  [row]   unread (tint background)   │
│  [row]   unread                     │
│  [row]   read                       │
│  [row]   read                       │
│  [follow_request row · w/ buttons]  │
│  …                                  │
│  PagingFooter "Loading more"        │
└─────────────────────────────────────┘
```

| Region | Notes |
|---|---|
| **TopBar** | Reuses `Shell.jsx::TopBar`. Title: localized "Notifications" (display type, 18px, sentence case). No back button — this is a tab root, not a pushed screen. |
| **Top-right action** | A text-only ghost button "Mark all read" (`Btn kind="ghost"`), sized small (the `Btn` primitive's default padding works). Disabled (50% opacity, `pointerEvents: none`) when no unread rows exist. No confirmation dialog — see §3.3. |
| **Scroll body** | Vertical list, `padding: '8px 16px 16px'` (matches `InboxScreen.jsx`). Rows separated by `8px` vertical gap. Each row is a `Card`-style surface (reusing the `Card` primitive). |
| **PagingFooter** | Cursor-pagination affordance (`Primitives.jsx::PagingFooter`). 20 rows per page, newest first. |
| **Empty state** | `Primitives.jsx::EmptyState` with glyph `通` (display kanji for "passage/message"), title and body strings per §4. |
| **Error state** | `Primitives.jsx::ErrorState` — calm tap-to-retry pattern; not red. |
| **Loading state (initial)** | `Primitives.jsx::LoadingState` centered in the scroll body. |

### 2.2 Row anatomy

Every row is a single `Card` (reuse `Primitives.jsx::Card`) with:

```
┌──────────────────────────────────────────────────────┐
│  ●  [avatar]  [actor name + verb]            [time]  │
│              [target preview snippet, 1 line]        │
│              [inline actions (follow_request only)]  │
└──────────────────────────────────────────────────────┘
```

| Slot | Content | Token |
|---|---|---|
| Unread marker (left) | `4px`-wide vertical bar OR a left-edge tint — **see §2.3 decision** | `--c-koh` |
| Avatar | `Avatar` primitive, `size={40}`, `tone="kinari"`. For soft-deleted actors → render with `initial="—"` and `tone="kinari"`; the avatar background is still kinari, glyph is the em-dash. | — |
| Actor + verb line | `font-body`, `15px`, `font-weight: 500`. Actor display name in `var(--fg-1)`, weight 600; verb + connective text in `var(--fg-1)`, weight 400. See §2.4 for verb strings. | `--fg-1`, `font-body` |
| Target preview | `font-body`, `13px`, `var(--fg-2)`, single line, ellipsis-truncated. The thing the actor acted on — review snippet for `toast`/`comment`, none for follow types (those rows are 1-line). | `--fg-2`, `font-body` |
| Timestamp | `font-mono`, `11px`, `var(--fg-3)`, right-aligned, vertically top-aligned with the avatar. Format: `elapsedShort()` matching the rest of the app (`2h`, `3d`, `5w`, etc.). | `--fg-3`, `font-mono` |
| Inline actions (follow_request only) | Right side of a second row beneath the verb line: `Btn kind="secondary"` (Decline) + `Btn kind="primary"` (Approve), each `flex: 1`, gap `8px`. Matches the existing `InboxScreen.jsx` button pair exactly. | — |

### 2.3 Read vs unread state — decision

**Chosen: subtle background tint** (NOT a left-edge bar).

| State | Card background | Card border |
|---|---|---|
| **Unread** | `--bg-tint-mizu` (`#EAF3F8`, "very light brand wash" — already designed for this purpose) | `--border-1` (unchanged) |
| **Read** | `--bg-card` (`#FFFFFF`, default Card background) | `--border-1` (unchanged) |

Rationale:
- The `--bg-tint-mizu` token's literal description in `colors_and_type.css` is "very light brand wash" — it exists specifically for this kind of subtle in-list emphasis. Reusing it for unread notification rows is exactly the intended use.
- A left-edge `4px` bar in `--c-koh` was the alternative. Rejected because: (a) it stacks an extra visual element against the warm-dot indicator already on the tab bar, doubling the "warm visual" footprint for one piece of information, and (b) the brand voice is "calm Japanese blue palette" — a tint reads quieter than an accent bar.
- The unread row stays cool-tinted (mizu); the dot on the tab bar stays warm (koh). Two senses, two registers — the eye distinguishes "I have notifications" (warm dot at edge of screen) from "this specific one is new" (cool tint on the row in-list).
- Transition from unread → read: crossfade `background` over `var(--dur-base)` (200ms, `--ease-out`). No layout shift, no other visual change.

### 2.4 Verb strings per notification type (English source)

The actor + verb line follows the pattern `[Actor display name] [verb phrase].` Sentence case throughout (KAMOS voice rule). The actor name is bolded (weight 600); the verb phrase is regular weight (400). Single sentence, no exclamation mark.

| Type | Pattern | Example (rendered) |
|---|---|---|
| `toast` | `{actor} toasted your check-in.` | **Aiko** toasted your check-in. |
| `comment` | `{actor} commented on your check-in.` | **Minjun** commented on your check-in. |
| `follow` | `{actor} started following you.` | **Sora T.** started following you. |
| `follow_request` | `{actor} requested to follow you.` | **Kentaro N.** requested to follow you. |
| `follow_approved` | `{actor} approved your follow request.` | **Tetsu** approved your follow request. |

Target preview snippets (under the verb line, 13px, single-line truncated):
- `toast` and `comment` → first 80 chars of the check-in's review text (or, if review is empty, the beverage name in italic — never empty).
- `follow` and `follow_approved` → omitted (1-line row).
- `follow_request` → optional 1-line bio if present, else omitted.

### 2.5 Soft-deleted actor rendering

When `actor_user_id` is `NULL` (the actor soft-deleted their account after the row was created), per SPEC §5.4:

| Slot | Soft-deleted rendering |
|---|---|
| Avatar | `Avatar` with `initial="—"` (em-dash, U+2014), `tone="kinari"`. No special border. |
| Actor name | Localized "Deleted user" (see §4 ARB keys), rendered in `var(--fg-2)` (one step muted from `--fg-1`), still weight 600 to preserve sentence rhythm. |
| Verb phrase | Unchanged ("toasted your check-in.", etc.). |
| Inline actions (follow_request) | The two buttons remain visible and functional — approving/declining a request from a deleted account is still a valid server action; the row will refresh on resolve. The Approve button label is unchanged; backend handles the no-op-or-error case. |
| Tap behavior | Tapping the row still navigates to the target (the check-in / the bare placeholder for the requester). Tapping the avatar or name is a no-op (no user page exists for a deleted account). |

### 2.6 Tap-to-open targets

| Type | Tap target |
|---|---|
| `toast` | The check-in detail page (`/checkins/:id`). |
| `comment` | The check-in detail page (`/checkins/:id`). Scroll-to-comments-section behavior is deferred to v1.1 — for MVP the screen opens at the top and the user scrolls to comments manually. |
| `follow` | The actor's profile (`/users/:username`). |
| `follow_request` | The actor's profile — but **only** when the tap lands outside the Approve / Decline button area. The buttons handle their own taps and do not bubble. |
| `follow_approved` | The actor's profile (the person whose request you sent and who approved you). |

The whole `Card` is the tap target except for the inline button region on `follow_request` rows. Use `HitTestBehavior.opaque` on the card and let the nested buttons absorb their own taps (matches the existing pattern in `profile_social_ux_expansion.md` §4 for the beverage-detail row).

---

## 3. Behavioral notes

### 3.1 Mark-on-scroll trigger

A row is marked read when **both** conditions are met:

1. The row is ≥ **50%** visible in the scroll viewport (`VisibilityDetector.visibleFraction >= 0.5`).
2. The 50%+ visibility has persisted for ≥ **500ms** continuously (debounce).

If the user scrolls fast — past a row in < 500ms — the row is **not** marked. This prevents drive-by reads during quick fling-scrolling. The debounce timer resets if visibility drops below 50% before 500ms elapses.

Implementation note for Flutter (`flutter-feature`): use `visibility_detector` package (already established Flutter pattern). The debounce + threshold logic should live in the row widget, not the list controller, so each row owns its own timer.

Marking-read fires `PATCH /notifications/:id/read` (or whatever the API contract names it — flag for `backend-engineer`). Network result is optimistic — the row's visual state flips to read immediately on the local timer firing. A failed network call does not re-flip the row visually; it logs and retries on the next mark or screen-open (idempotent server-side).

### 3.2 Tap-to-open mark-as-read

When a row is tapped to navigate to its target:
1. Mark the row read **synchronously** in local state (the row's tint clears on the next frame as the navigation transition runs).
2. Fire `PATCH /notifications/:id/read` in the background — fire and forget; same idempotent retry semantics as §3.1.

The user returning to the Notifications tab sees the row in its read state, no re-fetch required.

### 3.3 "Mark all read" — no confirmation

A single tap on the top-right text button fires `POST /notifications/read-all` immediately. No confirmation dialog. Rationale:
- Low-stakes operation — the user can re-find any notification's content (the underlying check-in, comment, profile) via the regular surfaces. Nothing is destroyed.
- Confirmations should be reserved for irreversible actions (delete account, delete check-in, delete collection).
- Matches Untappd / Instagram / Twitter convention; user expectation is "this just clears the badge."

Visual response: all currently-unread rows in the visible window crossfade from unread→read in unison (200ms, `--ease-out`). The unread dot on the Notifications tab clears in the same window. The button itself becomes disabled (50% opacity) until any new unread arrives via subsequent fetch / polling.

If the server fails the mark-all request, the rows snap back to unread and a calm inline error appears below the TopBar: localized "Could not mark all read. Try again." (see §4 ARB keys). The button re-enables.

### 3.4 Loading / pagination / error patterns

- **Initial fetch:** `LoadingState` primitive centered in the scroll body. No skeleton rows (KAMOS pattern; matches Feed).
- **Subsequent pages (cursor):** `PagingFooter` at the bottom of the list with `state="loading"` while the next page is in-flight; with `hasMore=false` it renders the "End of notifications" overline rule.
- **Pull-to-refresh:** standard platform pull-to-refresh fetches the newest cursor. No explicit visual for this beyond the platform spinner.
- **Empty state:** §4 strings, glyph `通`. No CTA button — there's nothing the user can usefully do to "make notifications happen" from this screen. The empty body copy gently points back at the social loop.
- **Error state (initial fetch fail):** `ErrorState` primitive — calm tap-to-retry. Not akane.
- **Error state (mid-list fetch fail):** Render last-loaded page; the `PagingFooter` flips to error mode (reuses `ErrorState` styling) with tap-to-retry-next-page.

### 3.5 Live updates while screen is open

Out of scope for this milestone. The screen does not poll. Updates arrive on next pull-to-refresh, next tab-focus, or app-resume. (Push notifications remain deferred per SPEC §9.) The Notifications tab's unread dot is fetched on app-start and on every tab-focus into a non-Notifications tab; flagged for `backend-engineer` as a `GET /notifications/unread` (boolean-or-count, returning only `{ has_unread: bool }` is sufficient).

---

## 4. Empty state & i18n appendix

### 4.1 Empty state copy (en source)

| Element | Text (en) | Suggested ARB key |
|---|---|---|
| Glyph | `通` (kanji, display type, `--c-gray-300`) | — (display only) |
| Title | "Nothing new" | `notificationsEmptyTitle` |
| Body | "Toasts, comments, and follows from other people show up here." | `notificationsEmptyBody` |

### 4.2 Screen labels (en source)

| Element | Text (en) | Suggested ARB key |
|---|---|---|
| Tab label | "Notifications" | `tabNotifications` |
| Discover tab label | "Discover" | `tabDiscover` |
| Screen title (TopBar) | "Notifications" | `notificationsTitle` |
| Mark all read button | "Mark all read" | `notificationsMarkAllRead` |
| Mark-all error inline | "Could not mark all read. Try again." | `notificationsMarkAllError` |
| End-of-list rule | "End of notifications" | `notificationsEnd` |
| Loading more (paging) | "Loading more" | reuse existing `loadingMore` |
| Soft-deleted actor label | "Deleted user" | `notificationsDeletedActor` |

### 4.3 Notification verb templates (en source)

Each template uses `{actor}` as a placeholder for the actor's display name. Flutter engineer should use the ARB plural/placeholder syntax (`{actor, plain}`). The actor's display name is rendered bold (weight 600) inline; this is a presentation concern, not a translation concern — the ARB string is a single sentence with the placeholder.

| Type | Text (en) | Suggested ARB key |
|---|---|---|
| `toast` | "{actor} toasted your check-in." | `notificationsVerbToast` |
| `comment` | "{actor} commented on your check-in." | `notificationsVerbComment` |
| `follow` | "{actor} started following you." | `notificationsVerbFollow` |
| `follow_request` | "{actor} requested to follow you." | `notificationsVerbFollowRequest` |
| `follow_approved` | "{actor} approved your follow request." | `notificationsVerbFollowApproved` |

### 4.4 Reused strings (already in ARB)

| Use | Existing key |
|---|---|
| Approve button on follow_request rows | `approve` (UI.approve in data.jsx) |
| Decline button on follow_request rows | `decline` (UI.decline in data.jsx) |
| Loading more (PagingFooter) | reuse existing `loadingMore` |
| Retry text on ErrorState | reuse existing `errorRetry` |

JA / KO translations are owned by `flutter-feature` (per the brief: "JA/KO translation lives in the Flutter task").

---

## 5. Component handoff summary

| Concern | File touched (this milestone) | Pattern reused |
|---|---|---|
| New screen | `ui_kits/mobile/components/NotificationsScreen.jsx` | `Card`, `Avatar`, `Btn`, `EmptyState`, `LoadingState`, `ErrorState`, `PagingFooter`, `TopBar` |
| New row variants demoed | (in `NotificationsScreen.jsx`) | one row per type, plus unread vs read, plus deleted-actor, plus empty |
| Tab bar update | `ui_kits/mobile/components/Shell.jsx::TabBar` | unchanged primitive choices, only tab list + dot indicator added |
| Demo wiring | `ui_kits/mobile/index.html` | matches existing screen-tile pattern |
| Sample data | `ui_kits/mobile/components/data.jsx` | new `NOTIFICATIONS` array, new `UI.notifications*` strings |
| Removed | none from `InboxScreen.jsx` in this milestone | the file stays on disk for one cycle to support the `/inbox`→`/notifications` redirect work; flag to `flutter-feature` to delete `InboxScreen` and `FOLLOW_REQUESTS` after migration is verified |
| `Badge` primitive | unchanged in `Primitives.jsx` | retained for potential numeric-badge future use; unused by this milestone |

---

## 6. Decision flags (historical)

The items below were open during the design phase. The notifications nav shipped end-to-end (the `/inbox` → `/notifications` redirect is live, the unread dot is fetch-on-focus), so most of these are now closed. Kept for design-decision provenance only.

1. **Inbox screen removal timing.** ~~Open.~~ Shipped: the kit's `InboxScreen.jsx` and `FOLLOW_REQUESTS` survived one cycle alongside the new Notifications tab; both have since been removed.
2. **Live-update channel for the unread dot.** This milestone is fetch-on-focus only. Realtime push (web socket / SSE / push notifications) is deferred to v1.1 per SPEC §9. If product wants polling on the Notifications tab while open, that's a behavior change — flag back; do not implement silently.
3. **Mark-on-scroll thresholds.** 50% visibility × 500ms is a recommendation matching common patterns (Instagram, X). If user-testing shows fast scrollers feel "behind" (lots of unread persisting after a scroll-through), shorten to 30% × 300ms — but do this as a unified update across mark-on-scroll behaviors app-wide, not just here.
4. **`elapsedShort()` for timestamps.** Reusing the existing helper from `shared/utils/elapsed_time.dart` (referenced in `profile_social_ux_expansion.md` §4). If the helper renders differently for `>1y` timestamps, that's fine — notifications older than a year are an edge case.
5. **`/inbox` redirect.** Backend / Flutter router concern — out of design scope. The design assumes the redirect happens transparently; design copies do not reference `/inbox` anywhere.

---

## 7. Token gaps noticed (not filled)

Per the brief, "DO NOT edit `design/colors_and_type.css` or introduce new tokens." The following are token gaps I noticed while doing this work — none are blocking; I left all of them unfilled so the orchestrator / user can decide whether to add tokens later:

1. **No dedicated "unread / new" semantic token.** I used `--c-koh` (Koh accent) for the unread dot and `--bg-tint-mizu` (light brand wash) for the unread row background. Both work and reuse existing tokens, but a future `--c-attention` / `--bg-unread` semantic token would make the intent more readable in widget code. Not blocking — the rationale is documented above.
2. **No tab-icon-with-badge primitive.** The unread dot is rendered inline inside `Shell.jsx::TabBar` as a positioned `<div>`. If we end up wanting badge indicators on other tabs (e.g., a count on Lists, a dot on Me for new follower), a small `TabBadge` primitive would be worth extracting. Not blocking — single use site for now.
3. **The 8px dot literal in `TabBar`** isn't drawn from a named "dot size" token — it's a 2× of the 4px base spacing. Consistent with the rest of the codebase (Avatar sizes are also passed as literals via the `size` prop), so I matched existing practice rather than invent a `--badge-dot-size` token for one use site.
