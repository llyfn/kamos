---
name: design-wireframe
description: "KAMOS UX/UI design skill. Use this to create wireframes, user flows, screen specs, design tokens, and API contract sketches for the KAMOS app. Invoke whenever design work, wireframing, screen layout, navigation flow, or design system work is requested."
---

# Design Wireframe Skill

Produces the full design deliverable set for KAMOS: wireframes, design tokens, screen specs, and API contract sketches that unblock backend and frontend work.

## Deliverables

All output goes to `_workspace/01_design/`. Create the directory first if it doesn't exist.

| File | Contents |
|------|----------|
| `wireframes.md` | Screen-by-screen wireframe descriptions or ASCII layouts |
| `design_tokens.md` | Color palette, typography scale, spacing, icons |
| `screen_specs.md` | Per-screen: components, states, interactions, i18n notes |
| `api_contracts.md` | Required API endpoints and JSON shapes per screen |

## Workflow

### 1. Inventory Screens

Map all screens from README features:
- Onboarding / Sign-in / Sign-up / Email verification
- Home feed (following)
- Beverage search & browse
- Beverage detail (flavor profile, check-ins)
- Brewery detail
- Check-in flow (search → detail → form → confirmation)
- User profile (own + other)
- Collection (inventory / wishlist tabs)
- Settings (locale switch, logout)

### 2. Navigation Architecture

Define the top-level navigation structure:
- Bottom navigation bar tabs (Home, Search, Check-in FAB, Collections, Profile)
- Stack flows within each tab
- Modal sheets (check-in form, flavor tag picker, venue search)
- Auth stack (separate from main app shell)

### 3. Wireframes

For each screen write a structured description covering:
- Header / AppBar contents
- Primary content area (list, detail card, form)
- Empty state
- Error state
- Loading skeleton

Use ASCII art for complex layouts:
```
┌─────────────────────────────┐
│  ← Back    Beverage Detail  │
├─────────────────────────────┤
│  [Image]   Name (EN/JP/KO)  │
│            Brewery · Region │
│  ⭐ 4.2    Nihonshu         │
├─────────────────────────────┤
│  Flavor Profile             │
│  ● Sweet  ● Dry  ● Fruity   │
├─────────────────────────────┤
│  Check-ins (234)            │
│  [Feed list ...]            │
└─────────────────────────────┘
```

### 4. Design Tokens

Define in `design_tokens.md`:
```
Colors:
  primary:       #3D2B1F  (deep brown — Koji)
  secondary:     #8B6F4E  (warm tan — Rice)
  accent:        #C45C26  (terracotta — sake cup)
  background:    #FAF7F2  (warm off-white)
  surface:       #FFFFFF
  error:         #D32F2F
  text-primary:  #1A1210
  text-secondary:#6B5B4E

Typography:
  Display: Noto Serif JP / weight 600 / 28sp
  Headline: Noto Serif JP / weight 500 / 22sp
  Body: Noto Sans / weight 400 / 16sp
  Caption: Noto Sans / weight 400 / 12sp
  (All three font families cover EN, JP, KO glyphs)

Spacing scale: 4, 8, 12, 16, 24, 32, 48 (dp)
Border radius: 4, 8, 16, 24 (dp)
```

### 5. API Contract Sketches

For each screen, list required endpoints and expected response shapes. Example:
```
Screen: Beverage Detail
GET /beverages/:id
Response:
{
  "id": "uuid",
  "name": {"en": "...", "ja": "...", "ko": "..."},
  "brewery": { "id": "uuid", "name": {"en": "..."} },
  "category": "nihonshu",
  "alcohol_pct": 15.5,
  "flavor_profile": ["sweet", "fruity", "light"],
  "avg_rating": 4.2,
  "checkin_count": 234
}
```

### 6. i18n Notes

For every text node that appears in a wireframe, note its ARB key. Flag any string that:
- Contains a proper noun requiring locale-specific form (beverage category names)
- Has grammatical structure that differs across EN/JP/KO (verb-final in JP/KO)
- Uses plurals (Flutter `intl` plural syntax)

## Output Checklist

- [ ] All README features have at least one corresponding screen
- [ ] Every screen has empty state and error state defined
- [ ] `api_contracts.md` covers all data requirements
- [ ] Design tokens include all three font families for i18n
- [ ] Category terminology follows README: "Nihonshu (Sake)" / "Shochu" in EN
