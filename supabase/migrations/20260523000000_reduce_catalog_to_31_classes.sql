-- Migration: Reduce catalog from 42 to 29 plants (31-class TFLite model alignment)
-- Date: 2026-05-23
--
-- Plants removed (not in 31-class MobileNetV2 TFLite model):
--   adelfa-001       (Adelfa / Nerium oleander — toxic, not an output class)
--   alagaw-001       (Alagaw / Premna odorata)
--   balanoy-001      (Balanoy / Ocimum basilicum)
--   bignay-001       (Bignay / Antidesma bunius)
--   dayap-001        (Dayap / Citrus aurantifolia)
--   gotu-kola-001    (Gotu Kola / Centella asiatica)
--   ipil-ipil-001    (Ipil-Ipil / Leucaena leucocephala — toxic, not an output class)
--   kahel-001        (Kahel / Citrus sinensis)
--   kamantigue-001   (Kamantigue / Impatiens balsamina)
--   mani-001         (Mani / Arachis hypogaea)
--   pandan-001       (Pandan / Pandanus amaryllifolius)
--   tuba-tuba-001    (Tuba-Tuba / Jatropha curcas — toxic, not an output class)
--   yerba-buena-001  (Yerba Buena / Mentha cordifolia — DOH-approved but not in current model)
--
-- Post-migration expected counts:
--   catalog_plants         = 29
--   catalog_safety         ≤ 29
--   catalog_habitat        ≤ 29
--   catalog_plant_anatomy  (variable — may have 0 or multiple parts per plant)
--
-- All child tables (catalog_medicinal_uses, catalog_preparation_methods,
-- catalog_safety, catalog_habitat, catalog_condition_plants, catalog_plant_anatomy)
-- carry ON DELETE CASCADE from catalog_plants — explicit deletes below are
-- included for auditability and to handle plant_metadata (no FK constraint).

-- Step 1: Delete from plant_metadata (no FK — must be manual)
DELETE FROM public.plant_metadata
WHERE plant_id IN (
  'adelfa-001',
  'alagaw-001',
  'balanoy-001',
  'bignay-001',
  'dayap-001',
  'gotu-kola-001',
  'ipil-ipil-001',
  'kahel-001',
  'kamantigue-001',
  'mani-001',
  'pandan-001',
  'tuba-tuba-001',
  'yerba-buena-001'
);

-- Step 2: Delete child rows (explicit — ON DELETE CASCADE covers these,
--          but listed for a clear audit trail)
DELETE FROM public.catalog_plant_anatomy
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

DELETE FROM public.catalog_condition_plants
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

DELETE FROM public.catalog_habitat
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

DELETE FROM public.catalog_safety
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

DELETE FROM public.catalog_preparation_methods
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

DELETE FROM public.catalog_medicinal_uses
WHERE plant_id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

-- Step 3: Delete from catalog_plants (parent — cascades remaining child rows)
DELETE FROM public.catalog_plants
WHERE id IN (
  'adelfa-001', 'alagaw-001', 'balanoy-001', 'bignay-001', 'dayap-001',
  'gotu-kola-001', 'ipil-ipil-001', 'kahel-001', 'kamantigue-001',
  'mani-001', 'pandan-001', 'tuba-tuba-001', 'yerba-buena-001'
);

-- Step 4: Drop ai_vision_summary column if it was ever added
--         (was added in v0.9.7 via app code but never via a SQL migration;
--          IF EXISTS makes this a no-op if absent)
ALTER TABLE public.catalog_plants  DROP COLUMN IF EXISTS ai_vision_summary;
ALTER TABLE public.plant_metadata   DROP COLUMN IF EXISTS ai_vision_summary;

-- Step 5: Verification query (comment out before committing to production)
-- SELECT COUNT(*) AS catalog_plants_count FROM public.catalog_plants;
-- Expected: 29
