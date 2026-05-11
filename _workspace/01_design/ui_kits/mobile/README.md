# KAMOS Mobile UI Kit

Recreation of the KAMOS Flutter app in HTML/JSX. The app is greenfield — no codebase exists — so these screens are designer interpretations of the [SPEC.md](../../README.md#sources).

## Structure
```
index.html              ← demo with three phones: live app + 2 deep screens
components/
  Primitives.jsx        Avatar, Label, Stars, Btn, Chip, Card, inline Icon set
  Shell.jsx             Phone frame, TopBar, TabBar, Sheet
  FeedScreen.jsx        Following feed with kanpai-mark toast reaction
  SearchScreen.jsx      Discover / search with category chips
  BeverageScreen.jsx    Beverage detail page
  CheckInScreen.jsx     Modal check-in flow
  ProfileLists.jsx      Profile (Me) + Collections (Lists)
  data.jsx              Sample catalog, feed, collections
```

## Five-tab structure
**Feed · Search · Check in · Lists · Me** — matches the spec's nouns. The center "Check in" tab is a raised circular button (Ai-iro), other tabs are hairline icons.

## What works
- Tab switching, search filtering & category chips
- Tap a beverage in Search → detail page with back nav
- "Check in" → rating, review, flavor tags, photo placeholders
- Toast reaction (KAMOS kanpai mark) on feed items toggles state with a soft scale animation
