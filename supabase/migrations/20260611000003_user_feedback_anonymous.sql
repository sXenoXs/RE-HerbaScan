-- =============================================================================
-- Migration: 20260611000003_user_feedback_anonymous.sql
-- HerbaScan User Feedback — add anonymous submission support
-- Applied: June 11, 2026
-- =============================================================================
--
-- Adds an is_anonymous column to user_feedback so users can choose whether
-- their feedback is linked to their account or submitted anonymously.
-- When is_anonymous = true, user_id is set to NULL.
-- =============================================================================

-- Add is_anonymous column with default false (existing feedback is identified)
ALTER TABLE public.user_feedback
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT false;

-- Make user_id nullable so anonymous feedback can have user_id = NULL
ALTER TABLE public.user_feedback
  ALTER COLUMN user_id DROP NOT NULL;

-- Update RLS policy: allow insert with NULL user_id for anonymous feedback
-- (Drop and recreate the insert policy to allow NULL user_id)
DROP POLICY IF EXISTS "Users can insert feedback" ON public.user_feedback;

CREATE POLICY "Users can insert feedback"
  ON public.user_feedback
  FOR INSERT
  WITH CHECK (
    (auth.uid() = user_id) OR (is_anonymous = true AND user_id IS NULL)
  );

-- Users can still read their own identified feedback
DROP POLICY IF EXISTS "Users can read own feedback" ON public.user_feedback;

CREATE POLICY "Users can read own feedback"
  ON public.user_feedback
  FOR SELECT
  USING (
    (auth.uid() = user_id) OR (is_anonymous = false AND public.is_admin())
  );

-- Admins can read all feedback (existing policy, ensure it still works)
-- The existing admin policy should still apply via is_admin() check
