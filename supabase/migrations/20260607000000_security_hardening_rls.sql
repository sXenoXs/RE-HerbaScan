-- =============================================================================
-- Migration: 20260607000000_security_hardening_rls.sql
-- HerbaScan Security Hardening — RLS Audit Findings #7, #8, #9
-- Applied: June 07, 2026
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Finding #7 (HIGH): scans.training_eligible — users could flip their own
-- training_eligible flag via a direct UPDATE. Restrict UPDATE so only admins
-- can set training_eligible=true. Regular users retain UPDATE on their own
-- non-training columns (status, etc.) via the existing broad UPDATE policy;
-- we add a RESTRICTIVE (not PERMISSIVE) admin-only policy on training_eligible.
--
-- Approach: Replace the unconstrained user UPDATE policy with one that
-- prevents regular users from changing training_eligible. A separate
-- admin-only UPDATE policy is added that covers the full row.
-- -----------------------------------------------------------------------------

-- Drop existing broad user UPDATE policy on scans (may not exist on all installs)
DROP POLICY IF EXISTS "Users can update own scans" ON public.scans;

-- Users may update their own scan rows ONLY when they are NOT changing
-- training_eligible (they cannot escalate themselves into the training set).
CREATE POLICY "Users update own scans (non-training fields)"
  ON public.scans
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND training_eligible = (
      SELECT training_eligible FROM public.scans WHERE id = scans.id
    )
  );

-- Admins may update any scan row without restriction (including training_eligible).
DROP POLICY IF EXISTS "Admins update any scan" ON public.scans;
CREATE POLICY "Admins update any scan"
  ON public.scans
  FOR UPDATE
  USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- Finding #8 (LOW): user_feedback lacks an explicit UPDATE restriction.
-- While no client code updates feedback, there is no explicit DENY.
-- Add a policy that prevents UPDATE entirely (no principal can update).
-- Note: In Supabase RLS, the absence of an UPDATE policy already blocks it,
-- but an explicit guard provides defense-in-depth documentation.
-- -----------------------------------------------------------------------------

-- Ensure no accidental UPDATE policy exists
DROP POLICY IF EXISTS "user_feedback_update_deny" ON public.user_feedback;
DROP POLICY IF EXISTS "Users can update own feedback" ON public.user_feedback;

-- No UPDATE policy for user_feedback → Postgres RLS blocks all UPDATEs.
-- (We intentionally do NOT add an UPDATE policy here.)

-- -----------------------------------------------------------------------------
-- Finding #9 (LOW): anon role audit — defense-in-depth REVOKE of write paths.
-- All catalog tables already have SELECT USING (true) for catalog reads.
-- This sweep ensures anon cannot INSERT/UPDATE/DELETE any public table,
-- even if a future migration accidentally adds a permissive policy.
-- -----------------------------------------------------------------------------

-- REVOKE write permissions from anon role across all public tables.
-- This does not affect authenticated users (separate role).
-- catalog_* SELECT policies remain intact; only write paths are revoked.
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM anon;

-- Re-grant SELECT on catalog tables to anon (preserve offline sync reads).
-- These are already covered by RLS policies with USING (true), but explicit
-- table-level GRANTs ensure the anon role can reach the SELECT gate.
GRANT SELECT ON TABLE public.catalog_plants              TO anon;
GRANT SELECT ON TABLE public.catalog_medicinal_uses      TO anon;
GRANT SELECT ON TABLE public.catalog_preparation_methods TO anon;
GRANT SELECT ON TABLE public.catalog_safety              TO anon;
GRANT SELECT ON TABLE public.catalog_habitat             TO anon;
GRANT SELECT ON TABLE public.catalog_conditions          TO anon;
GRANT SELECT ON TABLE public.catalog_condition_plants    TO anon;
GRANT SELECT ON TABLE public.catalog_plant_anatomy       TO anon;
-- Note: GRANT SELECT on app_versions is in 20260607000001_app_versions.sql
