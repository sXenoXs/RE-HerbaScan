-- HerbaScan: Plant catalog (master) for Admin Plant Metadata Editor.
-- Cloud-first editable catalog; app syncs to SQLite when online.
-- Exactly 42 plants (1-to-1 with ML model); no add/delete.

-- 1. Catalog plants (master)
CREATE TABLE IF NOT EXISTS public.catalog_plants (
  id TEXT PRIMARY KEY,
  common_name TEXT NOT NULL,
  scientific_name TEXT NOT NULL,
  local_name TEXT NOT NULL DEFAULT '',
  english_name TEXT NOT NULL DEFAULT '',
  family TEXT NOT NULL DEFAULT '',
  genus TEXT NOT NULL DEFAULT '',
  species TEXT NOT NULL DEFAULT '',
  morphology TEXT NOT NULL DEFAULT '',
  ecology TEXT NOT NULL DEFAULT '',
  habitat TEXT NOT NULL DEFAULT '',
  climate_notes TEXT DEFAULT '',
  image_url TEXT,
  is_doh_approved BOOLEAN NOT NULL DEFAULT false,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_catalog_plants_last_updated ON public.catalog_plants(last_updated DESC);

ALTER TABLE public.catalog_plants ENABLE ROW LEVEL SECURITY;

-- Anyone can read (for app sync when online)
DROP POLICY IF EXISTS "Anyone can read catalog_plants" ON public.catalog_plants;
CREATE POLICY "Anyone can read catalog_plants"
  ON public.catalog_plants FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
DROP POLICY IF EXISTS "Admins can insert catalog_plants" ON public.catalog_plants;
CREATE POLICY "Admins can insert catalog_plants"
  ON public.catalog_plants FOR INSERT
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update catalog_plants" ON public.catalog_plants;
CREATE POLICY "Admins can update catalog_plants"
  ON public.catalog_plants FOR UPDATE
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete catalog_plants" ON public.catalog_plants;
CREATE POLICY "Admins can delete catalog_plants"
  ON public.catalog_plants FOR DELETE
  USING (public.is_admin());

-- 2. Catalog medicinal uses
CREATE TABLE IF NOT EXISTS public.catalog_medicinal_uses (
  id SERIAL PRIMARY KEY,
  plant_id TEXT NOT NULL REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  condition TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  effectiveness TEXT NOT NULL DEFAULT '',
  active_compounds TEXT DEFAULT '',
  dosage TEXT DEFAULT '',
  duration TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_catalog_medicinal_uses_plant ON public.catalog_medicinal_uses(plant_id);

ALTER TABLE public.catalog_medicinal_uses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_medicinal_uses" ON public.catalog_medicinal_uses;
CREATE POLICY "Anyone can read catalog_medicinal_uses"
  ON public.catalog_medicinal_uses FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_medicinal_uses" ON public.catalog_medicinal_uses;
CREATE POLICY "Admins can insert catalog_medicinal_uses"
  ON public.catalog_medicinal_uses FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can update catalog_medicinal_uses" ON public.catalog_medicinal_uses;
CREATE POLICY "Admins can update catalog_medicinal_uses"
  ON public.catalog_medicinal_uses FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_medicinal_uses" ON public.catalog_medicinal_uses;
CREATE POLICY "Admins can delete catalog_medicinal_uses"
  ON public.catalog_medicinal_uses FOR DELETE USING (public.is_admin());

-- 3. Catalog preparation methods
CREATE TABLE IF NOT EXISTS public.catalog_preparation_methods (
  id TEXT NOT NULL,
  plant_id TEXT NOT NULL REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  condition TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  preparation_type TEXT NOT NULL DEFAULT '',
  steps TEXT NOT NULL DEFAULT '',
  step_details_json TEXT,
  schedule_json TEXT,
  dosage TEXT DEFAULT '',
  frequency TEXT DEFAULT '',
  duration TEXT DEFAULT '',
  warnings TEXT DEFAULT '',
  PRIMARY KEY (id, plant_id)
);

CREATE INDEX IF NOT EXISTS idx_catalog_prep_plant ON public.catalog_preparation_methods(plant_id);

ALTER TABLE public.catalog_preparation_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_preparation_methods" ON public.catalog_preparation_methods;
CREATE POLICY "Anyone can read catalog_preparation_methods"
  ON public.catalog_preparation_methods FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_preparation_methods" ON public.catalog_preparation_methods;
CREATE POLICY "Admins can insert catalog_preparation_methods"
  ON public.catalog_preparation_methods FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can update catalog_preparation_methods" ON public.catalog_preparation_methods;
CREATE POLICY "Admins can update catalog_preparation_methods"
  ON public.catalog_preparation_methods FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_preparation_methods" ON public.catalog_preparation_methods;
CREATE POLICY "Admins can delete catalog_preparation_methods"
  ON public.catalog_preparation_methods FOR DELETE USING (public.is_admin());

-- 4. Catalog safety (one row per plant)
CREATE TABLE IF NOT EXISTS public.catalog_safety (
  plant_id TEXT PRIMARY KEY REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  is_generally_safe BOOLEAN NOT NULL DEFAULT true,
  pregnancy_warning BOOLEAN NOT NULL DEFAULT false,
  known_side_effects JSONB DEFAULT '[]',
  drug_interactions JSONB DEFAULT '[]',
  strict_contraindications JSONB DEFAULT '[]'
);

ALTER TABLE public.catalog_safety ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_safety" ON public.catalog_safety;
CREATE POLICY "Anyone can read catalog_safety"
  ON public.catalog_safety FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_safety" ON public.catalog_safety;
CREATE POLICY "Admins can insert catalog_safety"
  ON public.catalog_safety FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can update catalog_safety" ON public.catalog_safety;
CREATE POLICY "Admins can update catalog_safety"
  ON public.catalog_safety FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_safety" ON public.catalog_safety;
CREATE POLICY "Admins can delete catalog_safety"
  ON public.catalog_safety FOR DELETE USING (public.is_admin());

-- 5. Catalog habitat (one row per plant)
CREATE TABLE IF NOT EXISTS public.catalog_habitat (
  plant_id TEXT PRIMARY KEY REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  known_coordinates JSONB DEFAULT '[]',
  region_names JSONB DEFAULT '[]',
  climate_notes TEXT DEFAULT ''
);

ALTER TABLE public.catalog_habitat ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_habitat" ON public.catalog_habitat;
CREATE POLICY "Anyone can read catalog_habitat"
  ON public.catalog_habitat FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_habitat" ON public.catalog_habitat;
CREATE POLICY "Admins can insert catalog_habitat"
  ON public.catalog_habitat FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can update catalog_habitat" ON public.catalog_habitat;
CREATE POLICY "Admins can update catalog_habitat"
  ON public.catalog_habitat FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_habitat" ON public.catalog_habitat;
CREATE POLICY "Admins can delete catalog_habitat"
  ON public.catalog_habitat FOR DELETE USING (public.is_admin());

-- 6. Conditions (for Condition Search)
CREATE TABLE IF NOT EXISTS public.catalog_conditions (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  icon_key TEXT NOT NULL DEFAULT 'healing',
  color_hex TEXT NOT NULL DEFAULT 'FF6366F1',
  is_default BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0
);

ALTER TABLE public.catalog_conditions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_conditions" ON public.catalog_conditions;
CREATE POLICY "Anyone can read catalog_conditions"
  ON public.catalog_conditions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_conditions" ON public.catalog_conditions;
CREATE POLICY "Admins can insert catalog_conditions"
  ON public.catalog_conditions FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can update catalog_conditions" ON public.catalog_conditions;
CREATE POLICY "Admins can update catalog_conditions"
  ON public.catalog_conditions FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_conditions" ON public.catalog_conditions;
CREATE POLICY "Admins can delete catalog_conditions"
  ON public.catalog_conditions FOR DELETE USING (public.is_admin());

-- 7. Condition–plant link (many-to-many)
CREATE TABLE IF NOT EXISTS public.catalog_condition_plants (
  condition_id INT NOT NULL REFERENCES public.catalog_conditions(id) ON DELETE CASCADE,
  plant_id TEXT NOT NULL REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  PRIMARY KEY (condition_id, plant_id)
);

CREATE INDEX IF NOT EXISTS idx_catalog_condition_plants_plant ON public.catalog_condition_plants(plant_id);

ALTER TABLE public.catalog_condition_plants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_condition_plants" ON public.catalog_condition_plants;
CREATE POLICY "Anyone can read catalog_condition_plants"
  ON public.catalog_condition_plants FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can insert catalog_condition_plants" ON public.catalog_condition_plants;
CREATE POLICY "Admins can insert catalog_condition_plants"
  ON public.catalog_condition_plants FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS "Admins can delete catalog_condition_plants" ON public.catalog_condition_plants;
CREATE POLICY "Admins can delete catalog_condition_plants"
  ON public.catalog_condition_plants FOR DELETE USING (public.is_admin());
