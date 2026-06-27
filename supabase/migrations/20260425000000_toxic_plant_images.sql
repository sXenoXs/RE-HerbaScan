-- Stores display image URLs for the informational toxic plants shown in the Browse screen.
-- One row per plant keyed by slug. Admin uploads images; users read them publicly.

CREATE TABLE IF NOT EXISTS public.toxic_plant_images (
  slug        TEXT PRIMARY KEY,
  common_name TEXT NOT NULL,
  image_url   TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.toxic_plant_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read toxic_plant_images"
  ON public.toxic_plant_images
  FOR SELECT
  USING (true);

CREATE POLICY "Authenticated write toxic_plant_images"
  ON public.toxic_plant_images
  FOR ALL
  USING (auth.role() = 'authenticated');

-- Pre-populate slugs so the admin screen can load them immediately.
INSERT INTO public.toxic_plant_images (slug, common_name) VALUES
  ('dumb-cane',               'Dumb Cane'),
  ('physic-nut-tuba-tuba',    'Physic Nut / Tuba-tuba'),
  ('snake-plant',             'Snake Plant'),
  ('cycads',                  'Cycads'),
  ('daphne',                  'Daphne'),
  ('angels-trumpet',          'Angel''s Trumpet'),
  ('lantana',                 'Lantana'),
  ('calla-lily',              'Calla Lily'),
  ('poinsettia',              'Poinsettia'),
  ('cacti-and-succulents',    'Cacti and Succulents'),
  ('rhus-wax-tree',           'Rhus / Wax Tree')
ON CONFLICT (slug) DO NOTHING;
