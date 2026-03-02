-- HerbaScan: 2D Interactive Plant Silhouette – anatomy parts (vector paths, part-specific content).
-- Synced to SQLite via CatalogSyncService; RLS uses public.is_admin().

CREATE TABLE IF NOT EXISTS public.catalog_plant_anatomy (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id TEXT NOT NULL REFERENCES public.catalog_plants(id) ON DELETE CASCADE,
  part_name TEXT NOT NULL,
  svg_path TEXT NOT NULL DEFAULT '',
  color_hex TEXT NOT NULL DEFAULT '4CAF50',
  z_index INTEGER NOT NULL DEFAULT 0,
  is_interactive BOOLEAN NOT NULL DEFAULT true,
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  conditions JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_catalog_plant_anatomy_plant_id ON public.catalog_plant_anatomy(plant_id);

ALTER TABLE public.catalog_plant_anatomy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read catalog_plant_anatomy" ON public.catalog_plant_anatomy;
CREATE POLICY "Anyone can read catalog_plant_anatomy"
  ON public.catalog_plant_anatomy FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can insert catalog_plant_anatomy" ON public.catalog_plant_anatomy;
CREATE POLICY "Admins can insert catalog_plant_anatomy"
  ON public.catalog_plant_anatomy FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update catalog_plant_anatomy" ON public.catalog_plant_anatomy;
CREATE POLICY "Admins can update catalog_plant_anatomy"
  ON public.catalog_plant_anatomy FOR UPDATE USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete catalog_plant_anatomy" ON public.catalog_plant_anatomy;
CREATE POLICY "Admins can delete catalog_plant_anatomy"
  ON public.catalog_plant_anatomy FOR DELETE USING (public.is_admin());
