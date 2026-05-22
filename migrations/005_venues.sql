-- 005_venues.sql — Phase 4.
--
-- Optional venue tag on check-ins, backed by Foursquare's Places API (Phase 4
-- post-MVP roadmap). Venues live as long as any check-in references them;
-- on check-in delete the FK is SET NULL and orphan venue rows are kept (cheap,
-- low cardinality). No background cleanup job in this phase.
BEGIN;

CREATE TABLE venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- foursquare_id is nullable so free-form (non-Foursquare) venues can also
  -- live here in a future phase. UNIQUE so we can upsert on conflict.
  foursquare_id TEXT UNIQUE,
  name TEXT NOT NULL,
  address TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  country TEXT,
  prefecture TEXT,
  locality TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (lat IS NULL OR (lat BETWEEN -90 AND 90)),
  CHECK (lng IS NULL OR (lng BETWEEN -180 AND 180))
);

CREATE INDEX idx_venues_country ON venues (country);
CREATE INDEX idx_venues_prefecture ON venues (prefecture);
CREATE INDEX idx_venues_name_tsv ON venues
USING gin (to_tsvector('simple', name));

ALTER TABLE check_ins
ADD COLUMN venue_id UUID NULL REFERENCES venues (id) ON DELETE SET NULL;

CREATE INDEX idx_check_ins_venue ON check_ins (venue_id) WHERE venue_id IS NOT NULL;

COMMIT;
