-- 004_widen_checkin_rating.sql — SPEC §4.2 update: rating step 0.5 → 0.25.
-- The 0.25 grid requires two decimal places. NUMERIC(3,1) → NUMERIC(3,2).
-- Existing 0.5-multiple values fit losslessly. The companion CHECK
-- constraint is rebuilt to enforce the new grid.

BEGIN;

ALTER TABLE check_ins
DROP CONSTRAINT check_ins_rating_valid;

ALTER TABLE check_ins
ALTER COLUMN rating TYPE NUMERIC(3, 2);

ALTER TABLE check_ins
ADD CONSTRAINT check_ins_rating_valid
CHECK (
  rating IS NULL OR (
    rating >= 0.5 AND rating <= 5.0
    AND (rating * 100)::INT % 25 = 0
  )
);

COMMIT;
