---
name: db-schema
description: "KAMOS PostgreSQL schema design skill. Use this to design database tables, write migration SQL files, define indexes, and document query patterns for the KAMOS beverage platform. Invoke whenever schema design, migration, table creation, or database modeling work is requested."
---

# DB Schema Skill

Designs the PostgreSQL data model for KAMOS: normalized tables, migration files, indexes, and annotated query patterns.

## Output Structure

```
_workspace/02_backend/db/
├── schema.md          — ERD narrative + design decisions
├── migrations/
│   ├── 001_initial.sql
│   ├── 002_beverage_categories.sql
│   └── ...
├── indexes.md
└── query_patterns.md
```

## Schema Design Workflow

### 1. Read API Contracts

Load `_workspace/01_design/api_contracts.md` first. Every response field must trace to a table column.

### 2. Entity Design Rules

Every table:
```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

Add a trigger for `updated_at`:
```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
-- repeat per table
```

i18n text fields: use `JSONB` with locale keys:
```sql
name_i18n JSONB NOT NULL DEFAULT '{}'
-- access: name_i18n->>'en', name_i18n->>'ja', name_i18n->>'ko'
```

### 3. KAMOS Entity Checklist

Write DDL for:

**Users & Auth**
```sql
users (id, username UNIQUE, email UNIQUE, email_verified, password_hash, google_sub, avatar_url, bio, locale)
email_verifications (id, user_id FK, token, expires_at, used_at)
```

**Beverage Catalog**
```sql
beverage_categories (id, slug, name_i18n)  -- 'nihonshu', 'shochu'
breweries (id, name_i18n, region, prefecture, founded_year, website, description_i18n)
beverages (id, brewery_id FK, name_i18n, category_id FK, subcategory, alcohol_pct NUMERIC(4,1),
           flavor_profile TEXT[], description_i18n, avg_rating NUMERIC(3,2), checkin_count INT)
```

**Check-ins & Reviews**
```sql
flavor_tags (id, name_i18n, slug UNIQUE)
venues (id, name, address, lat NUMERIC(9,6), lng NUMERIC(9,6), google_place_id)
check_ins (id, user_id FK, beverage_id FK, rating NUMERIC(3,1) CHECK (rating >= 0 AND rating <= 5),
           review_text, venue_id FK NULLABLE, price NUMERIC(8,2) NULLABLE, purchase_type TEXT,
           deleted_at TIMESTAMPTZ)
check_in_photos (id, check_in_id FK, storage_key, url, width INT, height INT, sort_order INT)
check_in_flavor_tags (check_in_id FK, flavor_tag_id FK, PRIMARY KEY (check_in_id, flavor_tag_id))
```

**Social**
```sql
follows (follower_id UUID FK REFERENCES users, followed_id UUID FK REFERENCES users,
         created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (follower_id, followed_id))
```

**Collections**
```sql
collections (id, user_id FK, beverage_id FK, type TEXT CHECK (type IN ('inventory','wishlist')),
             notes TEXT, UNIQUE (user_id, beverage_id, type))
```

### 4. Indexes

Document in `indexes.md` and add `CREATE INDEX` to migrations:
```sql
-- Feed query: check-ins by followed users, recent first
CREATE INDEX idx_check_ins_user_created ON check_ins (user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_follows_follower ON follows (follower_id);
CREATE INDEX idx_follows_followed ON follows (followed_id);

-- Beverage search
CREATE INDEX idx_beverages_category ON beverages (category_id);
CREATE INDEX idx_beverages_brewery ON beverages (brewery_id);
CREATE INDEX idx_beverages_name_gin ON beverages USING GIN (name_i18n);

-- User lookup
CREATE UNIQUE INDEX idx_users_username ON users (LOWER(username));
CREATE UNIQUE INDEX idx_users_email ON users (LOWER(email));
```

### 5. Query Patterns

Document in `query_patterns.md` with annotated SQL that the backend engineer will implement as Go repository functions:

```sql
-- Feed: recent check-ins from users I follow (cursor-based)
SELECT ci.*, u.username, u.avatar_url, b.name_i18n AS beverage_name, br.name_i18n AS brewery_name
FROM check_ins ci
JOIN follows f ON f.followed_id = ci.user_id
JOIN users u ON u.id = ci.user_id
JOIN beverages b ON b.id = ci.beverage_id
JOIN breweries br ON br.id = b.brewery_id
WHERE f.follower_id = $1
  AND ci.deleted_at IS NULL
  AND ci.created_at < $2  -- cursor
ORDER BY ci.created_at DESC
LIMIT 20;
```

## Migration File Format

```sql
-- 001_initial.sql
BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
  ...
);

COMMIT;
```

Each migration is wrapped in a transaction. Number sequentially. Never edit a deployed migration — add a new one.
