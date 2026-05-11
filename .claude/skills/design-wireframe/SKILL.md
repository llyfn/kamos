---
name: design-wireframe
description: "KAMOS UX/UI design skill. Use this to extend the design system at _workspace/01_design/: tokens (colors_and_type.css), brand document (README.md), mobile UI kit (HTML/JSX), and primitive previews. Invoke whenever design work, wireframing, screen layout, navigation flow, token changes, voice/copy decisions, or design system work is requested."
---

# Design Wireframe Skill

Extends the existing KAMOS design system at `_workspace/01_design/`. The system is already established — your job is to maintain it, not redesign it.

## Authoritative artifacts

Treat the existing files as canonical. If you change a decision, change it here — not in a parallel Markdown doc.

| File | Role |
|---|---|
| `_workspace/01_design/README.md` | Brand + content fundamentals + visual foundations + iconography + INDEX + open questions. Single source of truth for voice, palette, type, motion, icon rules. |
| `_workspace/01_design/colors_and_type.css` | All design tokens: colors (Japanese-blue palette + accents + semantic), type scale, 4-px spacing scale, radii, shadows, motion (`--ease-*`, `--dur-*`), layout widths. The only place hex / sp / dp / ms live. |
| `_workspace/01_design/preview/*.html` | One file per primitive — `buttons`, `tags-chips`, `beverage-card`, `check-in-card`, `type-display`, `type-body`, `colors-{blues,neutrals,semantic,accents}`, `spacing-scale`, `radii`, `elevation`, `iconography`, `form-inputs`, `logo`. |
| `_workspace/01_design/ui_kits/mobile/index.html` | Demo entrypoint: renders the live 5-tab phone plus deep screens via JSX. |
| `_workspace/01_design/ui_kits/mobile/components/*.jsx` | `Primitives`, `Shell`, `FeedScreen`, `SearchScreen`, `BeverageScreen`, `CheckInScreen`, `ProfileLists`, `data`, plus `ios-frame.jsx`. |

Do not introduce Markdown-only wireframes / spec / token files. Wireframes are runnable JSX, tokens are CSS variables.

## Non-negotiables (do not re-litigate)

- **Five tabs:** Feed · Search · Check in · Lists · Me. Center "Check in" tab is a raised Ai-iro circular button.
- **Palette:** Japanese blues — Mizu, Sora, Hanada, Ai (primary), Kon, Rurikon. Backgrounds Shironeri (page) / Kinari (warm card) — never pure white pages. Single warm accent **Koh** (terracotta), reserved for toast / kanpai moments only.
- **Type:** Shippori Mincho (display) · Noto Sans JP (body, covers en/ja/ko) · JetBrains Mono (IDs, ratios). Never go below 14 px.
- **No emoji in UI.** The toast control uses the KAMOS kanpai mark (`assets/logo_white.png` active, `assets/logo_mark.png` inactive).
- **No gradients, no repeating chrome patterns, no flat colored "feature" icons, no drawn illustrations of people.**
- **Cards:** 1 px hairline border + `--shadow-1` + `--radius-md` + 16 px padding. No left-border accent, no top stripe.
- **Casing:** sentence case for buttons / headers / menu items. Title Case only for proper nouns (beverage names, brewery names, places).
- **SPEC category strings — exact, do not abbreviate:**
    - en: `Nihonshu (Sake)` · `Shochu` · `Liqueur`
    - ja: `日本酒` · `焼酎` · `リキュール`
    - ko: `니혼슈 (사케)` · `쇼츄` · `리큐어`
- **Rating:** 0.5–5.0 in 0.5 steps; shown as `4.0 / 5.0`. ABV `15.5%` (one decimal, no space). Polishing ratio in mono as `Seimai 60%`.
- **i18n fallback:** missing `ja` or `ko` falls back to `en`; never empty strings.

## Workflow

### 1. Read before writing

Always read `_workspace/01_design/README.md` and `colors_and_type.css` first. The decision you're about to make is likely already documented — either reuse it or, if it must change, change it in the canonical file.

### 2. Token changes (rare)

If the work requires a new token (new semantic color, new radius, new spacing step), edit `colors_and_type.css`:

- Add the raw value to the appropriate group (colors, spacing, radii, shadows, motion, layout).
- Add a semantic alias if the token will be referenced from JSX (e.g., `--bg-surface-warm`, not `--c-kinari` directly in components).
- Never invent half-steps in the 4-px spacing scale.
- Mirror the new token's intent in the README's relevant section.
- SendMessage to `flutter-engineer` summarizing the change (Flutter `ThemeData` must stay in sync).

### 3. New screen

1. Add a new `<ScreenName>Screen.jsx` to `ui_kits/mobile/components/`.
2. Reuse `Primitives.jsx` (Avatar, Label, Stars, Btn, Chip, Card, Icon) and `Shell.jsx` (Phone, TopBar, TabBar, Sheet). Build new primitives only when an existing one cannot be parameterized.
3. Reference tokens via CSS custom properties (`var(--c-ai)`, `var(--space-4)`), never hex / pixel literals.
4. Wire the screen into `index.html` — either as a tab in `App` or as a deep-screen column in `Stage`.
5. Update `ui_kits/mobile/README.md`'s component map.
6. Cover at minimum: header / app-bar, primary content, empty state, error state, loading skeleton.

### 4. New primitive preview

1. Add `preview/<name>.html`, following the pattern of existing previews (small standalone HTML referencing `../colors_and_type.css`).
2. Cross-link it from the README's INDEX section if it represents a new design concept.

### 5. Voice & content

Apply the README's voice rules every time you write copy:

- Calm, specific, no exclamation marks except a true milestone (a first check-in, a milestone toast).
- Bilingual literacy: *Nihonshu (日本酒)*, *Junmai Daiginjo (純米大吟醸)* on first appearance; romaji-only after.
- Numbers: `4.0 / 5.0`, `15.5%`, `Seimai 60%`, currency localised.
- "You" for instructions and empty states. "My X" for owned things ("My Inventory", "My check-ins"). Third-person neutral for system text ("Akiyu Junmai was added to Wishlist.").
- Run every line past the vibe-check table in the README (Yes column vs. No column).

### 6. i18n discipline

When proposing a UI string, name the ARB key it will use (e.g., `feed.empty_state.cta`) and note any cross-locale fragility:

- Proper nouns requiring locale-specific form (category labels in the table above).
- Verb-final structure differences in ja / ko.
- Plurals — use Flutter `intl` plural syntax.

### 7. Substitution flags

Carry these forward in the README's "Open questions / caveats" section. Do not silently resolve them:

- Display font (Shippori Mincho recommended; swap via `--font-display`).
- Icon set (Phosphor for HTML mocks; real Flutter family pending).
- Koh accent retention.
- Any new flag you introduce.

## Output checklist

- [ ] New screen has a tab integration in `index.html` AND a component-map entry in `ui_kits/mobile/README.md`
- [ ] All hex / sp / dp / ms values reference tokens in `colors_and_type.css` — no raw literals in JSX
- [ ] Empty state and error state designed for every new screen
- [ ] Category labels use the **exact** SPEC strings for all three locales where shown
- [ ] No emoji anywhere in UI copy or empty states; toast control uses the kanpai mark
- [ ] Sentence case for UI strings; Title Case only for proper nouns
- [ ] All exclamation marks justified by a genuine milestone
- [ ] Rating displayed as `4.0 / 5.0`; ABV as `15.5%`; polishing ratio in mono
- [ ] Substitution flags carried forward in the README
- [ ] Any Flutter-visible decision summarized in a SendMessage to `flutter-engineer`
