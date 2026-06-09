-- Migration: Enable RLS on public.model_versions and add access policies
-- Date: 2026-05-24
--
-- Reason: Supabase Advisor flagged model_versions as "RLS Disabled in Public" (Critical).
-- The table was created directly in Supabase without RLS, exposing it to anyone
-- with the anon key (embedded in the APK).
--
-- Access pattern:
--   SELECT  → public (OtaModelService reads model_versions for all users — OTA updates)
--   INSERT  → admins only (AdminOverviewScreen logs new model deployments)
--   UPDATE  → admins only (AdminOverviewScreen marks a version active/inactive)
--   DELETE  → admins only

ALTER TABLE public.model_versions ENABLE ROW LEVEL SECURITY;

-- SELECT: anyone can read (OtaModelService needs this for non-admin users)
DROP POLICY IF EXISTS "Anyone can read model_versions" ON public.model_versions;
CREATE POLICY "Anyone can read model_versions"
  ON public.model_versions
  FOR SELECT
  USING (true);

-- INSERT: admins only
DROP POLICY IF EXISTS "Admins can insert model_versions" ON public.model_versions;
CREATE POLICY "Admins can insert model_versions"
  ON public.model_versions
  FOR INSERT
  WITH CHECK (public.is_admin());

-- UPDATE: admins only
DROP POLICY IF EXISTS "Admins can update model_versions" ON public.model_versions;
CREATE POLICY "Admins can update model_versions"
  ON public.model_versions
  FOR UPDATE
  USING (public.is_admin());

-- DELETE: admins only
DROP POLICY IF EXISTS "Admins can delete model_versions" ON public.model_versions;
CREATE POLICY "Admins can delete model_versions"
  ON public.model_versions
  FOR DELETE
  USING (public.is_admin());
