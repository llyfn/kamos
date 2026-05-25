# Profile / social UX expansion — design spec

Scope: visual decisions for the `feat/profile-social-ux-expansion` branch only. No new tokens. All references are to existing `KamosTokens`, `KamosSpacing`, `KamosCard`, `KamosChip`, `KamosPillButton`, `KamosAvatar`.

Plan source: `~/.claude/plans/analyze-the-current-project-transient-wadler.md`.

---

## 1. Me page AppBar

`MeProfileScreen` currently has no AppBar — wrap its `Scaffold` in one.

| Property | Value |
|---|---|
| Leading icon | `Icons.person_search_outlined` |
| Leading target | `context.push('/users/search')` |
| Leading tooltip | `userSearchTitle` ARB key |
| Actions[0] icon | `Icons.bookmark_outline` |
| Actions[0] target | `context.push('/collections')` |
| Actions[0] tooltip | localized "Lists" (reuse existing `tabLists` ARB key) |
| Title | none (omit `title:`) |
| Background | `t.bgPage` (Shironeri `#FCFAF6`) — matches page; no chrome seam |
| `elevation` | `0` |
| `scrolledUnderElevation` | `0` (no Material 3 surface tint on scroll) |
| `surfaceTintColor` | `Colors.transparent` |
| Icon size | `24` (Material default for AppBar) |
| Icon color | `t.fg1` (Sumi) |
| Tap target | `IconButton` default `48 × 48` — satisfies 44pt HIG floor |
| Toolbar height | `kToolbarHeight` (56) — default |

### Icon rationale

- `Icons.person_search_outlined` reads as "find people," distinct from `Icons.people_outline` which reads as "groups." The plan named `people_outline` as a placeholder; `person_search_outlined` is the intended action.
- `Icons.bookmark_outline` matches the existing Lists tab semantic ("things you saved"). `Icons.list_alt_outlined` is acceptable if the engineer prefers visual parity with the bottom tab's icon — pick one and use it in both Me + Other AppBars for consistency. **Decision below: use `Icons.bookmark_outline` everywhere this concept appears in AppBars; reserve `list_alt` for the bottom tab.**

---

## 2. Other user page AppBar

`OtherProfileScreen` already has `AppBar()`. Extend with the same right-side icon — no left-side users icon (back button only, framework-provided).

| Property | Value |
|---|---|
| Leading | default back button (no override) |
| Actions[0] icon | `Icons.bookmark_outline` (same as Me) |
| Actions[0] target | `context.push('/users/$username/lists')` |
| Actions[0] tooltip | localized `userCollectionsTitle` |
| Title | empty (omit) — keeps the surface quiet; profile shows its own name in the body |
| Background, elevation, tints, icon size/color | identical to Me AppBar (§1) |

---

## 3. Follow / Unfollow button on `OtherProfileScreen`

Replaces the Edit + Settings pill row in `_ProfileBody` when `isMe == false`. **One pill, full row width (`expand: true`).** Three states driven by `profile.followState` from backend:

| `follow_state` | Variant | Label (en) | Foreground | Background | Border |
|---|---|---|---|---|---|
| `none` | `KamosPillButton.primary` (filled) | `Follow` (`profileFollow`) | `#FFFFFF` | `t.ai` | — |
| `pending` | `KamosPillButton.secondary` (outlined) | `Requested` (`profileFollowRequested`) | `t.fgMuted` | transparent | `t.border1` |
| `accepted` | `KamosPillButton.secondary` (outlined) | `Following` (`profileFollowing`) | `t.ai` | transparent | `t.border1` |

Notes:

- Use `KamosPillButton` as-is. The two existing variants cover all three states; the `pending` and `accepted` rows differ only in label color, which `KamosPillButton.secondary` already supports via its label text style. **Pass color through `label` styling is not exposed** — if the engineer can't tint the label without modifying `KamosPillButton`, ship all three secondary states with `t.fg1` foreground and rely on the label text alone to distinguish. Do not add a new variant.
- Width: full single pill row, `expand: true`. The Edit + Settings asymmetric pair is replaced by one full-width button — this is the clearest social affordance and matches the rest of the app's "single primary CTA" pattern.
- Disabled (in-flight request): set `onPressed: null`. `KamosPillButton` already mutes fg/bg at 0.4/0.7 alpha for the primary variant; secondary uses `t.fgMuted`. No spinner glyph in the button — instead disable until the provider settles.
- **Unfollow confirmation:** show a small bottom sheet on `accepted` tap. Recommended (one sentence + two pills):
  - Sheet title (display, 18px Shippori Mincho, `t.fg1`): `Unfollow @username?`
  - Body (14px, `t.fg2`): one-line, e.g., `You won't see their check-ins in your feed.`
  - Actions row: `KamosPillButton.secondary` "Cancel" + `KamosPillButton.primary` "Unfollow"
  - Sheet uses 24px top corners (`KamosRadii.xl`), default sheet background, 20px padding, drag handle visible. Reuse the existing settings/account-deletion sheet pattern.
  - Rationale: follow is one tap; unfollow is socially heavier and benefits from a beat. Matches the SPEC's calm tone — "no surprise toggles."
- ARB keys (Flutter engineer adds): `profileFollow`, `profileFollowing`, `profileFollowRequested`, `profileUnfollow`, `profileUnfollowConfirmTitle`, `profileUnfollowConfirmBody`, `profileCancel` (reuse if exists).

---

## 4. Beverage detail — recent check-in row enrichment

File: `frontend/lib/features/beverages/screens/beverage_detail_screen.dart`, current row at lines 216–278.

Whole row tappable → `context.push('/check-ins/${r.id}')`. Wrap the `KamosCard` with `onTap:` (the widget already supports it). Inside the row, wrap **only** the avatar + username subtree in a nested `GestureDetector` → `context.push('/users/${r.user.username}')`. The nested gesture absorbs taps on that sub-region before the card's tap fires.

### Visual hierarchy (top → bottom inside the card)

1. **Header row** — avatar (32) · username (14/600) · rating (mono 11, right-aligned). _(Unchanged from today.)_
2. **Timestamp** — directly under the header row, 11px Noto Sans JP, `t.fg3`, format `elapsedShort(...)` (already exists in `shared/utils/elapsed_time.dart`, e.g. `2d`, `3w`). Aligned left under the username. Gap above: `KamosSpacing.xs` (4).
3. **Review text** — 13/1.5, `t.fg1`. Truncate at 140 chars + ellipsis (no "more" link — the whole row taps through). Gap above: `KamosSpacing.sm` (8) when timestamp present.
4. **Photo thumbnail strip** — sits **below** the text, full row width (under avatar column inset; align with text column for visual rhythm — i.e., start at the same x as the username). Gap above: `KamosSpacing.sm` (8).
5. **Tag chips** — `Wrap` with `KamosChip(kind: KamosChipKind.tag)`, spacing 6 / runSpacing 6. Gap above strip: `KamosSpacing.sm` (8). Tags only.

### Photo thumbnail strip

| Property | Value |
|---|---|
| Height | `64` |
| Tile aspect ratio | `1 : 1` (square) → tile is 64 × 64 |
| Tile radius | `8` (`KamosRadii.sm`) |
| Gap between tiles | `8` (`KamosSpacing.sm`) |
| Max visible tiles | `4` |
| Layout | horizontal `Row`, no scroll — beverage detail rows always render up to 4 inline. If `photos.length > 4`, render first 4 only (no `+N` overlay; this is a peek, not a gallery — the row taps to the full check-in). |
| Empty case | omit the strip entirely (no placeholder) |
| Image fit | `BoxFit.cover` |
| `memCacheWidth` | `64 * devicePixelRatio` (rounded) — keeps cache lean |
| Error fallback | `t.gray100` background + `Icon(Icons.broken_image_outlined, 18, t.fgMuted)` (same as `_CheckInPhotoGrid`) |

### Layout placement detail

Photos and chips sit **below** the text column — not inline beside it. The avatar stays in its left gutter; from the second row down (timestamp, review, photos, chips), content fills the full inner card width. Reuse the existing `Row` + `Expanded` shape: avatar in the leading slot, the right-side `Column` grows to include everything from the header row through chips.

### Inner card padding

Bump from `EdgeInsets.all(12)` to `EdgeInsets.all(14)` (the `KamosCard` default) — the row now has more vertical content and the tighter 12px padding cramps the photo strip. **Decision flag:** the explicit `padding: const EdgeInsets.all(12)` at line 227 can be removed to inherit the default.

---

## 5. Profile-tap target sizing (avatar + name)

Wrap the avatar + name subtree with `GestureDetector` (preferred over `InkWell` here — the parent surface usually already has an `InkWell` and we want no double-ripple) in:

- `frontend/lib/features/feed/widgets/check_in_card.dart` — `Row` at lines 49–78
- `frontend/lib/features/comments/widgets/comment_tile.dart` — header row
- `frontend/lib/features/beverages/screens/beverage_detail_screen.dart` — recent-check-in header row (avatar + username only)

| Property | Value |
|---|---|
| Tap region | the entire avatar + username column subtree (down to the username `Text`; do not include timestamp on the feed card — that's the parent row's tap target) |
| Minimum hit area | `44 × 44` logical pixels (iOS HIG). Avatars at 32/36 sit comfortably inside that; combined with the username text label, the hit area exceeds the floor naturally. No explicit `SizedBox` padding needed in feed / beverage-detail rows. For comment tiles, if the avatar+name visual width drops below 44, wrap the gesture region in a `SizedBox(height: 44)` to backfill. |
| Visual affordance on press | **none** — no ripple, no scale, no color shift. The KAMOS design language is quiet; profile-tap is a discoverable secondary action and should not announce itself visually. The parent `KamosCard` / `InkWell` still ripples for the primary tap (open check-in / open beverage), so taps register a system response regardless. |
| Hit-test behavior | `HitTestBehavior.opaque` on the `GestureDetector` so taps on the transparent space between the avatar and the username text still trigger. |

### Conflict-resolution rule

When a parent surface already has `onTap` (e.g., `KamosCard(onTap: …)` or the feed card's outer card tap → check-in detail), the nested profile gesture wins because Flutter's gesture arena resolves the innermost recognizer first when both are `opaque`. No need for `Listener` / explicit `absorb`. Confirmed pattern for the beverage-detail row where both the card (→ check-in detail) and a nested gesture (→ user page) coexist.

---

## Open decisions to flag to the engineer

1. **Bookmark vs. list_alt for the AppBar action icon.** Spec recommends `Icons.bookmark_outline`; the planning doc said `Icons.list_alt_outlined`. Going with `bookmark_outline` for the visual distinction from the bottom Lists tab. If engineer disagrees, swap both Me and Other AppBars together — never split.
2. **Unfollow confirm sheet vs. instant.** Spec recommends a confirmation sheet (calm, two-pill, no spinner). If product wants single-tap unfollow with an undo snackbar instead, that's a SPEC-level call — flag back, do not implement silently.
3. **`KamosPillButton` label color for `pending`/`accepted` states.** If tinting the secondary label isn't trivially exposed, ship both states with `t.fg1`. Do **not** add a new pill variant for this branch.
4. **No new tokens introduced.** If the engineer hits a measurement that doesn't exist in `KamosSpacing` / `KamosRadii`, surface it back here — do not invent a literal.
