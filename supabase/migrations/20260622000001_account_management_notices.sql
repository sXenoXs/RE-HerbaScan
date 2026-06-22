-- Migration: 20260622000001_account_management_notices
-- Adds three columns to public.profiles to support:
--   1. Force-verified notice: admin force-verified → user sees a one-time dialog on next login
--   2. Role change notice: admin promoted/demoted → user sees a one-time dialog on next login
--   3. Suspension reason: reason text shown on AccountSuspendedScreen when is_active = false

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS force_verified_notice BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS role_change_notice    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS suspension_reason     TEXT;

-- Allow the caller (admin or service role) to read/update these columns.
-- The existing admin RLS on profiles already allows admins to SELECT/UPDATE any row.
-- Standard users can SELECT their own row (needed to read the notice flags on login).
-- No new policies needed; the existing SELECT policy covers own-row reads.
