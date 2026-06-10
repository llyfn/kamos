# KAMOS — Product Specification (MVP)

> Named after 醸す (*kamosu*, "to brew/ferment"). A Japanese alcoholic beverage tracking and discovery platform, benchmarking Untappd.

> **Where the numbers come from.** Every numeric / regex / enum value cited in this document mirrors `specs/invariants.yaml`, the machine-readable source of truth. Code reads them from the generated constants in `backend/internal/spec` (Go) and `frontend/lib/core/spec/spec.dart` (`KamosSpec`); CI's `spec-codegen` gate fails on drift. When changing a value, edit the YAML first, run `scripts/gen-spec.sh`, then update the narrative here to match.

---

## 1. Overview

KAMOS lets users discover, rate, and log Japanese alcoholic beverages — primarily Nihonshu and Shochu — and follow other users' drinking journeys. The beverage database is canonical and curated; user activity layers on top of it through check-ins, collections, and a social feed.

**Platforms:** iOS + Android (Flutter)
**Backend:** Go REST API + PostgreSQL
**Locales:** English (`en`), Japanese (`ja`), Korean (`ko`)

---

## 2. Beverage Catalog

### 2.1 Categories & Subcategories

| Category (EN) | Category (JA) | Category (KO) | Example Subcategories |
|--------------|--------------|--------------|----------------------|
| Nihonshu (Sake) | 日本酒 | 니혼슈 (사케) | Junmai, Ginjo, Daiginjo, Nigori, Sparkling |
| Shochu | 焼酎 | 쇼츄 | Imo (Sweet potato), Mugi (Barley), Kome (Rice), Soba |
| Liqueur | リキュール | 리큐어 | Umeshu, Yuzu, Amazake, Craft spirits |

**Rules:**
- Category names in UI must follow the table above exactly — no abbreviation or substitution.
- Japanese terms apply in the `ja` locale only. EN and KO terms are fixed per the table.
- Subcategory list is extensible; new entries are admin-managed, not user-created.

### 2.2 Beverage Entry Fields

| Field | Type | Notes |
|-------|------|-------|
| Name | i18n text | EN + JA required; KO optional |
| Producer / Maker | Relation | → §2.3 |
| Category | Enum | See §2.1 |
| Subcategory | Text | Free from predefined list |
| Alcohol % | Decimal | e.g., 15.5% |
| Rice polishing ratio | Decimal | Nihonshu only (e.g., 60%) |
| Flavor profile | Multi-select tags | Predefined taxonomy (→ §4.3) |
| Region / Prefecture | Text | JA prefecture for JP products |
| Description | i18n text | Optional |
| Label image | URL | Canonical image, admin-managed |

### 2.3 Producer / Maker Fields

| Field | Type |
|-------|------|
| Name | i18n text (EN + JA required) |
| Prefecture / Region | Text |
| Founded year | Integer (optional) |
| Website | URL (optional) |
| Description | i18n text (optional) |

### 2.4 Database Curation

> **Recommended:** Admin-curated database for MVP. Users can *request* additions via a form (a simple feedback mechanism), but cannot directly add or edit canonical entries. This keeps data quality high and avoids moderation overhead at launch. User-contribution with moderation can be introduced post-MVP.

**Admin curation tooling.** Admins manage the canonical catalog directly from the admin SPA at `/beverages` and `/producers`: create, update, soft-delete, restore, and search (FTS on name across en/ja/ko, plus exact lookup by UUID, producer, or category slug). The user-submission queue at `/v1/admin/beverage-requests` remains the path for non-admin contributors (post-MVP Phase 5).

- Catalog soft-delete uses `deleted_at TIMESTAMPTZ`. Public reads filter `deleted_at IS NULL`; user-history reads (feed, check-ins, collections) intentionally surface tombstoned catalog rows so historical context is preserved.
- Producer soft-delete returns `409 PRODUCER_HAS_LIVE_BEVERAGES` while any live beverage still references the producer — admins must tombstone or reassign the children first.
- Every catalog mutation writes a row to `moderation_log` inside the same transaction as the write. `target_type` covers `beverage` and `producer`; `action` covers `create`, `update`, `soft_delete`, and `restore`.
- Admin user lookup is exact-match only on indexed columns: `id` (UUID), `username` (case-insensitive), `email` (case-insensitive).

---

## 3. User Accounts

### 3.1 Registration & Authentication

| Method | Flow |
|--------|------|
| Email | Register with email + password → verification email sent → account active after click |
| Google OAuth | OAuth2 via Google Sign-In → auto-create account on first login |

- Passwords: minimum 8 characters; stored as bcrypt hash.
- Email verification link expires in **24 hours**.
- Unverified accounts can log in but are prompted to verify; no functional restriction in MVP.

### 3.2 User Profile

| Field | Notes |
|-------|-------|
| Username | Unique, 3–30 chars, alphanumeric + underscore only, **case-insensitive** (stored lowercase) |
| Display name | Free text, up to 50 chars; defaults to username |
| Avatar | Uploaded image or Google profile photo |
| Bio | Up to 200 chars |
| Locale preference | `en` / `ja` / `ko`; defaults to device locale |
| Stats | Check-in count, unique beverages, followers, following |

> **Recommended on case sensitivity:** `@yamamoto` and `@Yamamoto` are the same user. Stored lowercase, displayed as entered at registration.

### 3.3 Account Actions

- Change display name, bio, avatar — anytime.
- Change email — requires re-verification of new address.
- Change password — requires current password.
- Delete account — soft-delete; username held for 30 days before release.

---

## 4. Check-in

A check-in is a user's log entry for a specific beverage at a specific moment.

### 4.1 Check-in Fields

| Field | Required | Notes |
|-------|----------|-------|
| Beverage | Yes | Selected from the catalog via search |
| Rating | No | 0.25–5.0 in **0.25 steps** (→ §4.2) |
| Review text | No | Up to 500 chars |
| Flavor tags | No | Multi-select from predefined taxonomy (→ §4.3) |
| Photos | No | Up to **1 photo** per check-in on submission. Existing multi-photo check-ins remain readable (the API still serves their full photo arrays). |
| Price | No | Numeric amount + currency; per-serving or per-bottle toggle |
| Purchase type | No | `on-premise` / `retail` / `gift` / `other` |

Venue is not included in MVP. See §9.

### 4.2 Rating Scale

0.25–5.0 in 0.25-step increments (20 levels). Optional per check-in; a check-in without a rating is valid ("I tried this").

Beverage average rating is computed as a running average and updated on every check-in. Displayed as `X.X / 5.0`.

### 4.3 Flavor Tag Taxonomy

Predefined, admin-managed list. Organized by dimension:

| Dimension | Example Tags |
|-----------|-------------|
| Sweetness | Dry, Off-dry, Sweet, Very sweet |
| Body | Light, Medium, Full |
| Acidity | Low, Crisp, Bright, Sharp |
| Character | Fruity, Floral, Earthy, Umami, Smoky, Nutty, Woody |
| Finish | Short, Clean, Lingering, Warming |

Tags are locale-aware (displayed in the user's locale). A check-in can have any number of tags across dimensions.

> **Recommended:** Fixed taxonomy for MVP to enable meaningful filtering and aggregated flavor profiles on beverage pages. User-submitted custom tags post-MVP.

### 4.4 Check-in Actions

- Edit a check-in: all fields editable except the beverage after submission. The UI renders a small italic "edited" marker next to the timestamp whenever `edited_at IS NOT NULL`.
- Delete a check-in: soft-delete; removed from feed and counts, but not permanently erased.
- A user can check-in the same beverage multiple times (like Untappd).

---

## 5. Social

### 5.1 Follow System

Two profile modes, user-selectable in settings:

| Mode | Follow behavior | Content visibility |
|------|-----------------|--------------------|
| **Public** (default) | Anyone can follow instantly | Check-ins and profile visible to all |
| **Private** | Follow requests require approval | Check-ins and full profile visible only to approved followers |

- Pending follow requests are shown in a notifications inbox (new: see §5.4).
- A user can approve or decline each request individually.
- Revoking a follow (unfollowing someone who follows you) removes them from your followers list.
- Follower and following counts are always visible regardless of privacy mode.
- Blocking: not in MVP scope.

### 5.2 Feed

The feed shows the user's own check-ins plus check-ins from users the current user follows. It doubles as a personal activity log and a social timeline; the UI label is "Activities".

- **Ordering:** Reverse chronological (newest first). No algorithmic ranking for MVP.
- **Pagination:** Cursor-based (infinite scroll); 20 items per page.
- **Feed item content:** User avatar + username, beverage name + producer, rating, review text (truncated at 140 chars with "more"), first photo if any, flavor tags, elapsed time ("2h ago").
- Check-ins from private users only appear in the feed of approved followers.

### 5.3 Toasts (Reactions)

A single-tap reaction on any check-in — called a **toast** (🍶).

- Any logged-in user can toast a check-in. One toast per user per check-in (toggle to un-toast).
- Toast count shown on the check-in card in the feed and on the check-in detail page.
- Toasting a check-in on a private profile requires being an approved follower.

### 5.4 Notifications

In-app notifications are surfaced on the **Notifications** tab. Push notifications remain deferred to v1.1.

**Event types:**

| Type | Trigger |
|------|---------|
| `toast` | Someone toasts my check-in (§5.3) |
| `comment` | Someone comments on my check-in |
| `follow` | Someone starts following me (public account, auto-accepted) |
| `follow_request` | Someone requests to follow me (private account) |
| `follow_approved` | A follow request I sent was approved |

**Rules:**

- Self-actions never produce a notification (toasting your own check-in writes no row).
- Deduped on `(recipient, type, actor, check_in_id)` where applicable — toggling a toast off and back on does not create a duplicate row.
- On approval, the original `follow_request` row is removed from the approver's inbox and a `follow_approved` row is created in the original requester's inbox.
- Soft-deleting the actor preserves the row (`actor_user_id` → NULL); the UI renders a localized "Deleted user" placeholder.
- Soft-deleting the referenced check-in or comment preserves the row.

**Read state:**

- Each row has a nullable `read_at` timestamp.
- Marked read when (a) the row scrolls into view, (b) it is tapped open, or (c) the user invokes **Mark all read**.
- The Notifications tab shows an **unread dot** (not a count) when any row has `read_at IS NULL`.

**UI:**

- Single screen at `/notifications`. The prior follow-request-only `/inbox` is removed; deep links to `/inbox` redirect to `/notifications`.
- Follow-request rows expose inline **Approve** / **Decline** actions; all other types are tap-to-open.
- Cursor-paginated, 20 per page, newest first.

**Retention:**

- Read notifications older than 180 days are hard-deleted by a daily background sweep. Unread rows are preserved regardless of age — they remain the recipient's pending TODOs until explicitly resolved (tapped, scrolled into view, or "Mark all read"). 180 days mirrors the inbox window used by comparable social platforms and keeps the partial-index read-set bounded for healthy accounts.

---

## 6. Collection

A collection is a user-created named list of beverages — like a playlist. Each user manages as many collections as they want.

### 6.1 Default Collections

Every new user starts with two pre-created collections:

| Collection | Meaning |
|------------|---------|
| **Inventory** | "I have this bottle at home" |
| **Wishlist** | "I want to try this" |

These behave identically to user-created collections. They can be renamed or deleted.

### 6.2 Rules

- A beverage can be in **multiple collections simultaneously** — collections are independent lists, not mutually exclusive states.
- Checking in a beverage does not automatically alter any collection (decoupled by design).
- Each entry (beverage × collection) can have an optional note up to 200 chars (e.g., "2022 vintage, from Isetan").
- No quantity tracking in MVP — membership is binary (in the list or not).

### 6.3 Collection Management

- **Create**: name required (up to 50 chars); created empty.
- **Rename**: anytime.
- **Delete**: removes the collection and all its entries; requires confirmation.
- **Add beverage**: from beverage detail page or check-in screen → opens a multi-select collection picker. New collections can be created inline from the picker.
- **Remove beverage**: from the collection list view or beverage detail page.

### 6.4 Visibility

Collections are **private by default** — visible only to the owner, regardless of profile privacy setting. Owners may flip a collection's visibility to public; non-owners see only the owner's public collections via `GET /v1/users/{username}/collections`.

---

## 7. Beverage Discovery

Beyond the social feed, users can discover beverages through:

- **Search**: full-text search by beverage name or producer name, across all locales.
- **Browse by category**: tap a category to see all beverages in it, sortable by avg rating or newest.
- **Browse by producer**: all beverages from a producer on its detail page.
- **Beverage detail page**: shows catalog info, avg rating, flavor profile aggregated from all check-ins, and a list of recent check-ins.

> **Recommended:** No personalized recommendations or editorial "featured" picks in MVP. These require either a recommendation engine or editorial ops — both out of scope.

---

## 8. Internationalization

| Locale | Code | Coverage |
|--------|------|----------|
| English | `en` | Full — all UI strings |
| Japanese | `ja` | Full — all UI strings |
| Korean | `ko` | Full — all UI strings |

**Rules:**
- Locale follows the user's in-app preference (set in profile), defaulting to device locale.
- If a beverage has no `ko` name, fall back to `en` name in the KO locale.
- All user-generated content (reviews, notes) is stored as-entered; no translation.
- Category terminology is non-negotiable — see §2.1 table.

---

## 9. Out of Scope (MVP)

The following are explicitly out of MVP scope.

Four items originally listed here were reopened for post-MVP (v1.1) on 2026-05-14 and shipped end-to-end by Phase 7:

- **Venue / location on check-ins** — Phase 4. Foursquare Places API, not Google Places.
- **Flat comments on check-ins** — Phase 6. Author-editable (PATCH /v1/comments/{id}); UI shows an "edited" marker. Threaded comments remain out of scope.
- **Public collections** — Phase 6.
- **User-submitted beverage additions** — Phase 5. Admin moderation workflow.

Still out of scope (no plans):

- **Threaded comments** (multi-level / replies) — flat comments only, see above
- **Push notifications** — follow request inbox (§5.4) is in-app only
- **Web client** for end users (the post-MVP admin web client is a separate operator tool)
- **Apple Sign-In**
- **Beverage scanning** (barcode / label recognition)
- **Blocking / muting users**
- **Personalized recommendations / editorial "featured" picks**
- **Export / data portability**
