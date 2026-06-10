-- Lower check_ins rating floor from 0.5 to 0.25 (SPEC §4.2: 20 levels, 0.25..5.0).
BEGIN;

-- Existing rows are all >= 0.5 which satisfies the new floor; no data migration needed.
ALTER TABLE check_ins
  DROP CONSTRAINT check_ins_rating_valid,
  ADD CONSTRAINT check_ins_rating_valid
    CHECK (
      rating IS NULL OR (
        rating >= 0.25 AND rating <= 5.0
        AND (rating * 100)::int % 25 = 0
      )
    );

COMMIT;
