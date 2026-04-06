-- Fix infinite recursion in RLS: admin policies that SELECT from profiles cause
-- Postgres to re-evaluate profiles RLS when checking "is this user admin?", which
-- triggers the same admin policy again. Use a SECURITY DEFINER function so the
-- check runs with definer rights and does not recurse.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Profiles: admin policies use is_admin() instead of subquery on profiles
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
CREATE POLICY "Admins can select all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update any profile is_active" ON public.profiles;
CREATE POLICY "Admins can update any profile is_active"
  ON public.profiles FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Scans: admin policies use is_admin()
DROP POLICY IF EXISTS "Admins can select all scans" ON public.scans;
CREATE POLICY "Admins can select all scans"
  ON public.scans FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update scan status" ON public.scans;
CREATE POLICY "Admins can update scan status"
  ON public.scans FOR UPDATE
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete any scan" ON public.scans;
CREATE POLICY "Admins can delete any scan"
  ON public.scans FOR DELETE
  USING (public.is_admin());

-- Plant metadata: admin policies use is_admin()
DROP POLICY IF EXISTS "Admins can select plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can select plant_metadata"
  ON public.plant_metadata FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can insert plant_metadata"
  ON public.plant_metadata FOR INSERT
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can update plant_metadata"
  ON public.plant_metadata FOR UPDATE
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete plant_metadata" ON public.plant_metadata;
CREATE POLICY "Admins can delete plant_metadata"
  ON public.plant_metadata FOR DELETE
  USING (public.is_admin());
