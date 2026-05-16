-- 006_venue_value_constraints.sql
-- Backstop length caps on venue user-controlled fields. Application-layer
-- domain.CheckinVenue.Validate is the primary enforcement; these CHECKs
-- catch any code path that bypasses the validator and protect against
-- direct DB writes during admin operations (Phase 5).
--
-- Also drops idx_venues_name_tsv (no current reader; was created
-- speculatively in 005). Re-add when free-form local venue search lands.
BEGIN;
ALTER TABLE venues ADD CONSTRAINT venues_name_length CHECK (char_length(name) BETWEEN 1 AND 200);
ALTER TABLE venues ADD CONSTRAINT venues_address_length CHECK (address IS NULL OR char_length(address) <= 500);
ALTER TABLE venues ADD CONSTRAINT venues_country_length CHECK (country IS NULL OR char_length(country) <= 100);
ALTER TABLE venues ADD CONSTRAINT venues_prefecture_length CHECK (prefecture IS NULL OR char_length(prefecture) <= 100);
ALTER TABLE venues ADD CONSTRAINT venues_locality_length CHECK (locality IS NULL OR char_length(locality) <= 100);
ALTER TABLE venues ADD CONSTRAINT venues_foursquare_id_length CHECK (foursquare_id IS NULL OR char_length(foursquare_id) BETWEEN 1 AND 100);
DROP INDEX IF EXISTS idx_venues_name_tsv;
COMMIT;
