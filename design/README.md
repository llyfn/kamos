# KAMOS Design System

> Named after **醸す (kamosu)**, the Japanese verb for *brewing / fermenting*.
> A discovery and tracking platform for Japanese alcoholic beverages — Nihonshu, Shochu, and beyond.

KAMOS is to Japanese craft spirits what Untappd is to beer: a place to log what you've tried, discover what's next, and share the experience with people who care as much as you do.

---

## Sources

| Source | Path | Notes |
|---|---|---|
| Logo | `assets/logo.png` (recolored from original brief artwork) | Two ceramic cups in a *kanpai* / cheers gesture |
| Spec & overview | `llyfn/kamos` (private GitHub repo) — `README.md`, `SPEC.md` | Product spec only; **no UI codebase exists yet**, so this design system is greenfield, anchored to the spec |

> Reader does not need access to the source repo; the spec content used here is summarised in this README.

## Product context

- **Platforms:** iOS + Android, built in Flutter. (No web client in MVP.)
- **Backend:** Go REST API + PostgreSQL.
- **Locales:** English (`en`), 日本語 (`ja`), 한국어 (`ko`) — all three are first-class.
- **Catalog scope:** Nihonshu (日本酒), Shochu (焼酎), Liqueur (リキュール — Umeshu, Yuzu, Amazake, craft).
- **Core nouns:** Beverage · Brewery · User · Check-in · Toast (kanpai-mark reaction) · Collection (Inventory, Wishlist, custom).
- **Curation:** Admin-curated catalog at MVP; users request additions via feedback.

### Things the product is *not*
Not a venue/check-in-where app. Not a sommelier rating service. Not a marketplace. Not a translator of reviews. Not a recommender — the feed is reverse-chronological, period.

---

## CONTENT FUNDAMENTALS

KAMOS sounds like a knowledgeable friend at the bar — never a sommelier lecturing, never a hype account, never a dictionary. Calm, specific, respectful of the craft.

### Voice & tone
- **Calm and confident.** No exclamation marks except in genuinely celebratory moments (a first check-in, a milestone toast).
- **Specific over poetic.** "Junmai Ginjo from Akita" beats "elegant rice spirit." Names, regions, ratios, breweries are the texture.
- **Respectful, never reverent.** This is a daily-driver tracking app. We don't worship sake, we drink it.
- **Bilingual literacy without translation.** Japanese terms keep their kanji + romaji on first appearance: *Nihonshu (日本酒)*, *Junmai Daiginjo (純米大吟醸)*. Romaji-only is fine after.

### Pronouns & grammar
- **Second-person ("you")** for instructions and empty states. *"You haven't checked in anything yet."*
- **First-person ("I" / "my")** for user-owned things. *"My Inventory", "My check-ins"*. Never "your collection".
- **Third-person, neutral** for system text. *"Akiyu Junmai was added to Wishlist."*

### Casing
- **Sentence case** for everything: buttons, headers, menu items, navigation. ("Add to wishlist", not "Add To Wishlist".)
- **Title Case for proper nouns only:** beverage names, brewery names, places. *Dassai 23, Kuromatsu Kenbishi, Niigata.*
- Category labels in §2.1 of the spec are non-negotiable: **Nihonshu**, **Shochu**, **Liqueur** in EN; **日本酒**, **焼酎**, **リキュール** in JA; **니혼슈 (사케)**, **쇼츄**, **리큐어** in KO.

### Numbers & units
- ABV: `15.5%` (one decimal, percent sign, no space).
- Polishing ratio: `60%` (Nihonshu only; label as "Seimai 60%").
- Ratings: `4.0 / 5.0` always. Half-steps only (`0.5`, `1.0`, ..., `5.0`).
- Currency: localised; show the currency symbol (`¥1,200`, `₩9,800`, `$12`).

### Emoji
- **No emoji in UI.** Period. The toast reaction uses the **KAMOS kanpai mark** (`assets/logo_white.png` on Koh, `assets/logo_mark.png` for inactive states), never an emoji.
- Inline kanji glyphs (醸, 酒, 焼) are encouraged when they earn their place in display type.

### Vibe checks (good vs bad)

| ✅ Yes | ❌ No |
|---|---|
| "You toasted Aiko's check-in." | "Cheers! 🥂 You just toasted Aiko's amazing check-in! 🎉" |
| "Tried 47 beverages this year." | "Wow, you've crushed 47 sakes this year! 🔥" |
| "Search breweries, beverages, prefectures." | "Find your next favorite drink ✨" |
| "No check-ins yet. Tap **+** to log your first." | "Looks a bit empty in here! Why not log your first sip?" |
| "Kuromatsu Kenbishi · Hyōgo · Junmai" | "An incredible sake from Japan you HAVE to try" |

---

## VISUAL FOUNDATIONS

### Concept in one line
*A quiet ceramic shop in Kyoto at dusk, lit from inside.* Calm Japanese blues, undyed-silk paper, hairline rules, generous negative space, and one warm accent — only ever for the moment of the toast.

### Color
- Built around four **traditional Japanese blues** (色名): **Mizu-iro** (水色, water), **Sora-iro** (空色, sky), **Hanada** (縹, mid), **Ai-iro** (藍, indigo — brand primary), with **Kon** (紺, deep navy) for grounding.
- Page background is **Shironeri (白練)** `#FCFAF6` — undyed silk; never pure white.
- Cards are pure white **or** **Kinari (生成)** `#F4EFE6` — unbleached paper — for warm-feeling surfaces (brewery profiles, hero cards).
- One accent: **Koh (香)** terracotta `#C97B5A`, retained from the original logo lineage. Only appears around **toast** and *kanpai* moments — not for general CTAs.
- Status colors (matcha green, akane red, yamabuki gold) are dialed back, never neon.
- Imagery is **cool-leaning, soft**, no heavy saturation. No grain. No black-and-white.

### Type
- **Display / headings:** *Shippori Mincho* — a contemporary mincho with woodblock-cut character. Used for beverage names, hero numerics, brewery names.
- **Body / UI:** *Noto Sans JP* — neutral, comprehensive CJK, identical metrics across `en` / `ja` / `ko`.
- **Mono:** *JetBrains Mono* — only for IDs, polishing ratios, percentages.
- Always pair with proper line-heights in `colors_and_type.css`. Never go below 14px.
- *(Substitution flag: Shippori Mincho is the recommended display face. If the user prefers another mincho, swap `--font-display` and the system follows.)*

### Spacing & layout
- 4-pixel spacing scale (`--space-1` … `--space-12`). Never invent half-steps.
- Mobile design width: **420 px**. Most check-in / feed surfaces target this.
- Generous outer margins (`--space-5` = 20 px) — KAMOS feels uncrowded.
- Vertical rhythm prefers **negative space over dividers**; use a divider (`var(--border-1)` hairline) only when grouping is structural.

### Backgrounds & textures
- **No gradients.** Solid washes or hairline-bordered surfaces.
- **No repeating patterns** in chrome. (One exception: a faint asanoha / hemp-leaf pattern is permitted as a brewery-page decorative band — opacity ≤ 6%.)
- **No drop-shadow elevation theatre.** Cards sit on the page via a 1px border + a single soft shadow `--shadow-1` — that's it.
- **Imagery treatment:** beverage label photos are framed in white with a 1px hairline + `--radius-md`. Brewery hero images are full-bleed *only* on the brewery detail page.

### Borders & shadows
- Borders are 1px hairlines (`--border-1`) by default; emphasise with `--border-2`.
- Shadow scale is short and soft: `--shadow-1`, `--shadow-2`, `--shadow-3`.
- A **"protection gradient"** (the dark wash behind hero text on photos) is allowed *only* on full-bleed brewery covers; everywhere else, use a card.

### Corner radii
- Buttons & chips: **pill** (`--radius-pill`).
- Cards & modals: **12 px** (`--radius-md`).
- Bottom sheets: **24 px top corners only** (`--radius-xl`).
- Inputs: **8 px** (`--radius-sm`).
- Avatars: full circle.

### Cards
- White or Kinari background, 1 px hairline border, `--shadow-1`, 12 px radius, 16 px internal padding. No colored top stripe, no left-border accent.
- Beverage cards always include: label image (square, 56–64 px), name in Shippori Mincho, brewery + region in body small, rating + toast count in mono.

### Motion
- **Easing:** `--ease-out` (`cubic-bezier(0.2, 0.7, 0.2, 1)`) for entrance; `--ease-in-out` for transitions between states. **No bounces.**
- **Duration:** `--dur-fast` 120 ms (taps, hovers), `--dur-base` 200 ms (cards/sheets), `--dur-slow` 320 ms (page transitions).
- Crossfades over slides; gentle 4–8 px translate on entrance, never 16+.
- The single sanctioned "celebratory" moment is the **toast tap**: the kanpai mark scales 1 → 1.15 → 1 over 240 ms with `--ease-out`, and the count number flips with a vertical translate. Nothing else bounces.

### Hover & press states
- Hover (web previews only): background tint `var(--bg-tint-mizu)` or 4% darken; cards may raise from `--shadow-1` to `--shadow-2`.
- Press (mobile): subtle scale `0.98` + 8% darken; never colour-shifts to a new hue.
- Disabled: 40% opacity on text, 100% on background — never grayscale-only.

### Transparency & blur
- Backdrop blur (`backdrop-filter: blur(20px)`) only on the **bottom sheet handle area** and the **iOS-style nav bar over scrolled content**, never decoratively.
- Translucent overlays use `rgba(15, 35, 80, 0.5)` — kon-iro at 50%.

### Fixed elements
- Bottom tab bar is always fixed (Flutter `BottomNavigationBar` analogue): 5 tabs — **Feed · Search · Check-in · Lists · Me**. The center "Check-in" tab is a raised circular Ai-iro button; the others are hairline icons.
- Top app bar is **not** fixed by default — scrolls away — except on the Check-in flow where the action button must remain reachable.

---

## ICONOGRAPHY

KAMOS uses **Phosphor Icons** (regular weight, 20px on UI, 24px on tab bar).
- **Why Phosphor:** clean geometric strokes, neutral, has full coverage for what we need (search, plus, bookmark, user, list, heart, camera, x, chevron) at 1.5 stroke width — matches Shippori Mincho's calm cut.
- **Substitution flag:** Phosphor is a substitute pending real Flutter icon decisions. The Flutter app may instead use the bundled Material Symbols or a custom set; this design system uses Phosphor for HTML mocks. **Please confirm.**
- **Loading:** for HTML mocks, Phosphor is loaded from the official CDN (`https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css`). For production, install `phosphor-flutter` or your icon family of choice.

### Custom glyphs (KAMOS-specific)
- **Kanpai mark (toast)** — `assets/logo_white.png` (white-on-Koh active state) and `assets/logo_mark.png` (kon-iro on neutral, inactive). This is the brand mark itself, retasked as the toast icon.
- **Logo mark** (`assets/logo.png`) — two ceramic cups in *kanpai*; never cropped, never re-coloured (use `assets/logo_mono.png` for single-colour contexts).

### Hard rules
- **No emoji in UI labels, copy, or empty states.** Ever. The toast control uses the brand kanpai mark, not an emoji.
- **No flat colored circle "feature" icons** with white glyphs in them — that's an enterprise-SaaS trope, not us.
- **No drawn illustrations of people**. If we ever need illustration, it's woodblock-style botanical (rice stalk, sweet potato, plum branch) — at present we have none, and we'd rather use type and negative space.
- **Avatars** fall back to a Kinari background with the user's first initial in Shippori Mincho — never auto-generated coloured tiles.

---

## INDEX

```
README.md                  ← you are here
SKILL.md                   ← skill manifest (Claude Code compatible)
colors_and_type.css        ← all design tokens (vars + classes)

assets/
  logo.png                 Recolored brand mark (Ai-iro + Kon-iro)
  logo_mono.png            Single-color (Kon-iro) for monochrome contexts

preview/                   Cards rendered into the Design System tab
  type-display.html        ...etc

ui_kits/
  mobile/                          Flutter app recreation in HTML/JSX
    README.md                      Component map + SPEC compliance notes
    index.html                     Demo: live 5-tab app + locale toggle + every flow rendered
    components/
      data.jsx                     i18n catalog, breweries, feed, collections, follow requests, ME
      Primitives.jsx               Avatar · Label · Stars · StarsInput (0.5 steps) · Btn · Chip · Card · Icon
                                   EmptyState · LoadingState · ErrorState · PagingFooter
                                   Toggle · FormField · TextField · TextArea · SegmentedControl
                                   Row · PhotoTile · Badge · LocaleContext / useLocale
      Shell.jsx                    Phone frame, TopBar, TabBar, Sheet
      FeedScreen.jsx               Following feed with toast reaction + bell badge → inbox
      SearchScreen.jsx             Discover · category chips (exact SPEC strings) · recent + no-results
      BeverageScreen.jsx           Beverage detail · link to brewery · CTAs to check-in + collection picker
      CheckInScreen.jsx            Modal check-in flow · 0.5-step rating · counter · 4-photo grid · price · purchase · serving
      ProfileLists.jsx             Lists (Collections) + Profile (Me) with locale toggle
      AuthScreen.jsx               Sign in · Create account · Forgot password · Verify email · Google OAuth
      EditProfileScreen.jsx        Display name + bio + avatar
      SettingsScreen.jsx           Email + password · privacy toggle · locale · account-deletion confirm sheet
      InboxScreen.jsx              Follow request inbox · Approve / Decline
      BreweryScreen.jsx            Brewery detail · listing of all beverages
      CollectionPickerSheet.jsx    Multi-select sheet with inline new-collection
      CollectionDetailScreen.jsx   Collection contents · rename + delete with confirmation

fonts/                     (empty — Google Fonts loaded via colors_and_type.css)
```

### Where to start
- Designing a screen? → start from `colors_and_type.css` + `ui_kits/mobile/index.html`.
- Pitching the brand? → use the visuals from `preview/` plus the recoloured logo.
- Working in Claude Code? → read `SKILL.md`, then this README.

---

## COVERAGE — SPEC features × JSX files

| SPEC domain | Surfaces | Files |
|---|---|---|
| Auth (§3.1) | Sign in, Create account, Forgot password, Verify email, Google OAuth | `AuthScreen.jsx` |
| User profile (§3.2) | Profile view, stats, locale toggle | `ProfileLists.jsx::ProfileScreen` |
| Account actions (§3.3) | Edit display name + bio + avatar; change email + password; delete account with 30-day hold | `EditProfileScreen.jsx`, `SettingsScreen.jsx` |
| Privacy mode (§5.1) | Public/Private toggle, private pill on profile | `SettingsScreen.jsx`, `ProfileLists.jsx` |
| Beverage catalog (§2.1–§2.2) | Category overline + chips with exact i18n strings | `data.jsx::CATEGORY_LABELS`, `SearchScreen.jsx`, `BeverageScreen.jsx` |
| Beverage detail (§7) | Catalog info, avg rating, aggregated flavor, recent check-ins, brewery link | `BeverageScreen.jsx` |
| Brewery detail (§2.3, §7) | i18n name + region + founded + website + beverage list | `BreweryScreen.jsx` |
| Check-in (§4) | 0.5-step rating, 500-char review, ≤4 photos, price + currency, per-serving / per-bottle, purchase type, serving style | `CheckInScreen.jsx` |
| Rating widget (§4.2) | 0.5-step input + display | `Primitives.jsx::StarsInput` + `Primitives.jsx::Stars` |
| Toast reactions (§5.3) | Kanpai-mark toggle with animation | `FeedScreen.jsx::FeedItem` |
| Feed (§5.2) | Reverse-chronological list + cursor pagination footer | `FeedScreen.jsx`, `Primitives.jsx::PagingFooter` |
| Follow-request inbox (§5.4) | Approve / Decline list, badge on bell | `InboxScreen.jsx`, `Primitives.jsx::Badge` |
| Collections (§6) | List of collections, default `Inventory` + `Wishlist`, custom lists | `ProfileLists.jsx::ListsScreen` |
| Collection detail (§6) | Contents, rename, delete with confirmation | `CollectionDetailScreen.jsx` |
| Collection picker (§6.3) | Multi-select sheet with inline create | `CollectionPickerSheet.jsx` |
| Search / discovery (§7) | Full-text search across i18n names; category filter chips; recent + no-results | `SearchScreen.jsx` |
| i18n (§8) | en / ja / ko at runtime; `ko→en`, `ja→en` fallback | `data.jsx::t` + `Primitives.jsx::useLocale` |
| Empty / loading / error | Calm type-driven empty states; hairline spinner; retryable error | `Primitives.jsx::EmptyState/LoadingState/ErrorState` |

---

## i18n layout check

Every screen was walked across `en`, `ja`, and `ko` via the demo's locale toggle. Notes:

- **Category chips on Search** are the widest surface. With four chips in a single horizontal row, `Nihonshu (Sake)` overflows the visible area on a 390-wide phone in EN. Mitigation already in place: the chip strip uses `overflow-x: auto` so it scrolls — no truncation, no line-break. Acceptable but flagged for Flutter; consider wrapping to two rows if Flutter test devices show a worse cut-off.
- **Buttons** are widest in KO (`로그인으로 돌아가기`, `비밀번호 재설정`). Currently fit within the 280-wide Auth form column. No truncation in any tested locale.
- **CheckInScreen segmented controls** (per-serving / per-bottle) are widest in EN (`Per serving` / `Per bottle`). They fit on 390-wide phones. JA (`一杯` / `一本`) is narrowest; the control auto-sizes.
- **Profile stat tiles** use `Followers / フォロワー / 팔로워` — all fit. Korean is the longest at 3 chars on the overline; still fine.
- **No proper-noun line-breaks** are forced. The beverage display name (`Shippori Mincho`) naturally wraps on word boundaries; we never split a kanji compound.

---

## Open questions / caveats for the user

- 🟡 **Display font (Shippori Mincho)** is a substitution recommendation — please confirm or specify your preferred mincho. Swap by changing `--font-display` in `colors_and_type.css`.
- 🟡 **Icon set (Phosphor)** is a substitution — confirm or replace with the real Flutter set. The kit ships a small inline SVG icon set (`Primitives.jsx::Icon`) to stay self-contained; Flutter will pick its own family.
- 🟡 **Koh accent retention** — the brand has a single warm accent (terracotta Koh `#C97B5A`), retained from the original logo lineage. We use it only for the *toast* reaction and the Wishlist glyph background. Tell us if you want it cut entirely (single-hue brand) — `colors_and_type.css::--c-koh` would be removed and Wishlist would default to Kinari.
- 🟡 **Toast / kanpai mark in i18n** — the icon is glyph-free; the word "toast" only appears in microcopy. Confirm the localised verb (currently rendered passively as part of feed cards, not as a button label).
- 🟡 **Star half-step glyph (`⯨`)** — the U+2BE8 half-star is used by `Stars` and `StarsInput` to render 0.5 increments. It renders inconsistently across operating systems. Flutter should substitute a real half-fill icon path (Material `star_half`, Phosphor `Star fill 50%`, or a custom SVG).
- 🟡 **Photo handling** — the kit shows placeholder tiles; real camera roll integration is Flutter's call. The 4-photo cap is enforced UI-side in `CheckInScreen` and must also be enforced server-side per SPEC §4.1.
