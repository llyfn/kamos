# KAMOS Mobile UI Kit

Runnable recreation of the KAMOS Flutter app in HTML/JSX. Babel-standalone compiles the JSX at load time — no build step. Open `index.html` directly.

## Structure
```
index.html                     ← live 5-tab app + locale toggle + every screen
ios-frame.jsx                  ← phone chrome (loaded indirectly via Shell.jsx)
components/
  data.jsx                     i18n-ready catalog, producers, feed, collections, follow requests, ME
  Primitives.jsx               Avatar, Label, Stars, StarsInput, Btn, Chip, Card, Icon,
                               EmptyState, LoadingState, ErrorState, PagingFooter,
                               Toggle, FormField, TextField, TextArea, SegmentedControl,
                               Row, PhotoTile, Badge, LocaleContext + useLocale
  Shell.jsx                    Phone frame, TopBar, TabBar, Sheet
  FeedScreen.jsx               Following feed · kanpai-mark toast · cursor "Loading more"
  SearchScreen.jsx             Discover · category chips (exact SPEC strings) · recent searches · no-results
  BeverageScreen.jsx           Beverage detail · producer link · check-in / list CTAs
  CheckInScreen.jsx            Modal flow · 0.25-step RatingSlider (nullable, Clear) ·
                               review + 1-photo Row · flat flavor chips + browse sheet ·
                               Location row (Foursquare) · price (¥/₩/$ + per-serving/bottle) ·
                               full-width bottom Post button (AppBar action removed)
  ProfileLists.jsx             Lists (Collections) + Profile (Me) · in-profile locale toggle
  AuthScreen.jsx               Sign in · Create account · Forgot password · Verify email · Google OAuth
  EditProfileScreen.jsx        Display name + bio · avatar change · username read-only
  SettingsScreen.jsx           Email + password · privacy toggle · locale · soft-delete (30d hold)
  InboxScreen.jsx              [legacy] Follow request inbox — superseded by NotificationsScreen;
                               kept for the /inbox → /notifications redirect milestone
  NotificationsScreen.jsx      Unified notifications (SPEC §5.4) · 5 row types · unread tint ·
                               Mark all read · inline Approve/Decline on follow_request
  ProducerScreen.jsx           Producer detail (SPEC §2.3, §7) · listing of all beverages
  CollectionPickerSheet.jsx    Multi-select sheet + inline new-collection
  CollectionDetailScreen.jsx   Collection contents · rename + delete with confirmation
```

## Five-tab structure

**Feed · Lists · Discover · Notifications · Me** — post-MVP nav rewrite per `design/notifications_ux.md` §1. No center FAB; all five tabs use the same hairline-icon style. The Notifications tab shows an unread dot (color `--c-koh`, never a count) when any row is unread; clears on tab-focus + on "Mark all read".

Discover is the renamed Search tab (same screen content; route + label change only).

## What works (interactive)
- Tab switching, search filtering with locale-correct category chips
- Tap a beverage → detail page → back nav
- "Check-in" → continuous 0.25-step rating slider (Clear affordance, nullable), 500-char review beside a 1-photo square, flat flavor-tag chips + browse sheet, Location row, price + currency + per-serving/bottle, full-width Post at the bottom
- Toast reaction toggles the kanpai mark (`1 → 1.15 → 1` over 240 ms)
- Notifications tab unread dot lights up when any row is unread; the unified inbox renders inline Approve / Decline on `follow_request` rows
- Profile → Edit profile / Settings (privacy toggle, delete-account confirmation sheet)
- Beverage detail → producer link → producer page lists all beverages from that producer
- Lists tab → Collection detail → rename / delete
- Beverage detail "List" button opens the collection picker (multi-select + inline create)
- Locale toggle in the heading (and on the profile) swaps EN ↔ JA ↔ KO across all screens

## SPEC compliance points (cross-checked by qa-inspector)

- Category strings render **exact** per locale: `Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)`, `Shochu` / `焼酎` / `쇼츄`, `Liqueur` / `リキュール` / `리큐어`. Source of truth: `data.jsx::CATEGORY_LABELS`.
- Rating: `StarsInput` (display + legacy input) produces 0.5 increments; the new `RatingSlider` on `CheckInScreen` produces 0.25 increments across `0.5..5.0` (19 stops) and `null` for unrated. `StarsDisplay` rounds 0.25 values visually to half/full stars — no schema change. Format `x.xx / 5.0` on the compose screen; `4.0 / 5.0` everywhere else (per SPEC §4.2 post-redesign).
- Review counter on `CheckInScreen` enforces 500 chars; the Post button is disabled if the review exceeds 500 (defensive, since `maxLength` already blocks input).
- Photos: 1 fixed-size square tile on the compose screen (cap dropped from 4 → 1 per redesign brief); existing multi-photo check-ins still render on feed cards and detail screens.
- Feed pagination: `PagingFooter` renders the cursor-style "Loading more" affordance; SPEC §6.6 page size of 20 is implicit.
- Username: `Yamamoto` (display, case preserved) and `@yamamoto` (handle, stored lowercase) — see `data.jsx::ME`.
- i18n fallback: `t(node, locale)` falls back `ko→en`, `ja→en`. Demo strings include cases where `ko` is omitted to verify the fallback.
- Default collections (`Inventory`, `Wishlist`) carry `isDefault: true` for explanatory copy but are otherwise identical to user-created ones.
- Privacy: profile pill renders when `user.privacy === 'private'`; the Notifications tab shows an unread dot when any row is unread (pending follow_requests included); private check-ins gated to approved followers is documented (rendering layer only; gate enforced server-side).
