-- Add needs_strict_contraindications to catalog_safety for plants that require
-- prominent "use with strict caution" warnings (e.g. Kamias, Kamoteng Kahoy, Kakawate).

ALTER TABLE public.catalog_safety
  ADD COLUMN IF NOT EXISTS needs_strict_contraindications BOOLEAN NOT NULL DEFAULT false;

-- Backfill for Kamias, Kamoteng Kahoy, Kakawate (plant_id from catalog_plants)
UPDATE public.catalog_safety
  SET needs_strict_contraindications = true
  WHERE plant_id IN ('kamias-001', 'kamoteng-kahoy-001', 'kakawate-001');
