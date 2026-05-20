# KAMOS Mobile UI Kit

Runnable recreation of the KAMOS Flutter app in HTML/JSX. Babel-standalone compiles the JSX at load time — no build step. Open `index.html` directly.

## Structure
```
index.html                     ← live 5-tab app + locale toggle + every screen
ios-frame.jsx                  ← phone chrome (loaded indirectly via Shell.jsx)
components/
  data.jsx                     i18n-ready catalog, breweries, feed, collections, follow requests, ME
  Primitives.jsx               Avatar, Label, Stars, StarsInput, Btn, Chip, Card, Icon,
                               EmptyState, LoadingState, ErrorState, PagingFooter,
                               Toggle, FormField, TextField, TextArea, SegmentedControl,
                               Row, PhotoTile, Badge, LocaleContext + useLocale
  Shell.jsx                    Phone frame, TopBar, TabBar, Sheet
  FeedScreen.jsx               Following feed · kanpai-mark toast · cursor "Loading more"
  SearchScreen.jsx             Discover · category chips (exact SPEC strings) · recent searches · no-results
  BeverageScreen.jsx           Beverage detail · brewery link · check-in / list CTAs
  CheckInScreen.jsx            Modal flow · 0.5-step StarsInput · 500-char counter · 4-photo grid
                               · price (¥/₩/$ + per-serving/per-bottle) · purchase + serving chips
  ProfileLists.jsx             Lists (Collections) + Profile (Me) · in-profile locale toggle
  AuthScreen.jsx               Sign in · Create account · Forgot password · Verify email · Google OAuth
  EditProfileScreen.jsx        Display name + bio · avatar change · username read-only
  SettingsScreen.jsx           Email + password · privacy toggle · locale · soft-delete (30d hold)
  InboxScreen.jsx              Follow request inbox · Approve / Decline
  BreweryScreen.jsx            Brewery detail (SPEC §2.3, §7) · listing of all beverages
  CollectionPickerSheet.jsx    Multi-select sheet + inline new-collection
  CollectionDetailScreen.jsx   Collection contents · rename + delete with confirmation
```

## Five-tab structure

**Feed · Search · Check in · Lists · Me** — matches the SPEC nouns. The center "Check in" tab is a raised circular Ai-iro button; the others are hairline icons.

## What works (interactive)
- Tab switching, search filtering with locale-correct category chips
- Tap a beverage → detail page → back nav
- "Check in" → 0.5-step rating input, 500-char review counter, 4-photo grid with add/remove, price + currency + per-serving/bottle, purchase + serving chips
- Toast reaction toggles the kanpai mark (`1 → 1.15 → 1` over 240 ms)
- Bell icon in the feed opens the follow-request inbox with Approve / Decline
- Profile → Edit profile / Settings (privacy toggle, delete-account confirmation sheet)
- Beverage detail → brewery link → brewery page lists all beverages from that brewery
- Lists tab → Collection detail → rename / delete
- Beverage detail "List" button opens the collection picker (multi-select + inline create)
- Locale toggle in the heading (and on the profile) swaps EN ↔ JA ↔ KO across all screens

## SPEC compliance points (cross-checked by qa-inspector)

- Category strings render **exact** per locale: `Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)`, `Shochu` / `焼酎` / `쇼츄`, `Liqueur` / `リキュール` / `리큐어`. Source of truth: `data.jsx::CATEGORY_LABELS`.
- Rating: `StarsInput` produces values in `{ 0, 0.5, 1.0, … 5.0 }`. `0` represents "no rating" — the **Post** button stays enabled (rating is optional per SPEC §4.2). Format `4.0 / 5.0`.
- Review counter on `CheckInScreen` enforces 500 chars; the Post button is disabled if the review exceeds 500 (defensive, since `maxLength` already blocks input).
- Photos: 4-tile grid; tiles flip between add and filled+remove states; counter shows `n / 4`.
- Feed pagination: `PagingFooter` renders the cursor-style "Loading more" affordance; SPEC §6.6 page size of 20 is implicit.
- Username: `Yamamoto` (display, case preserved) and `@yamamoto` (handle, stored lowercase) — see `data.jsx::ME`.
- i18n fallback: `t(node, locale)` falls back `ko→en`, `ja→en`. Demo strings include cases where `ko` is omitted to verify the fallback.
- Default collections (`Inventory`, `Wishlist`) carry `isDefault: true` for explanatory copy but are otherwise identical to user-created ones.
- Privacy: profile pill renders when `user.privacy === 'private'`; inbox badge counts pending requests; private check-ins gated to approved followers is documented (rendering layer only; gate enforced server-side).
