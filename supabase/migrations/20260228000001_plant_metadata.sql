-- HerbaScan: Plant metadata overrides (admin-editable text only). Catalog fixed to 42 plants; no add/delete.
-- Run after 20260228000000_profiles_admin_and_email.sql.

CREATE TABLE IF NOT EXISTS public.plant_metadata (
  plant_id TEXT PRIMARY KEY,
  description TEXT,
  safety_warnings TEXT,
  preparation_steps_json TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.plant_metadata ENABLE ROW LEVEL SECURITY;

-- Only admins can select/insert/update/delete
DROP POLICY IF EXISTS "Admins can select plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can select plant_metadata"
  ON public.plant_metadata FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can insert plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can insert plant_metadata"
  ON public.plant_metadata FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can update plant_metadata"
  ON public.plant_metadata FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can delete plant_metadata"
  ON public.plant_metadata FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );
