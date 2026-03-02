-- HerbaScan: Add is_active and email to profiles for admin user management.
-- Run in Supabase Dashboard → SQL Editor after 20260223000000_herbarium_schema.sql.

-- Add columns to profiles (idempotent)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

-- Sync email from auth.users on insert (update trigger)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role, email)
  VALUES (NEW.id, 'user', NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Email is synced from app on sign-in (AuthProvider._loadRole). Optionally add trigger on auth.users in Dashboard if needed.

-- Backfill existing profiles with email from auth.users (one-time)
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND (p.email IS NULL OR p.email != u.email);

-- Admins: select all profiles (for user list)
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
CREATE POLICY "Admins can select all profiles"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles self
      WHERE self.id = auth.uid() AND self.role = 'admin'
    )
  );

-- Admins: update is_active on any profile (for deactivate)
DROP POLICY IF EXISTS "Admins can update any profile is_active" ON public.profiles;
CREATE POLICY "Admins can update any profile is_active"
  ON public.profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles self
      WHERE self.id = auth.uid() AND self.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles self
      WHERE self.id = auth.uid() AND self.role = 'admin'
    )
  );
