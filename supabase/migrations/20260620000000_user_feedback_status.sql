-- Migration: 20260620000000_user_feedback_status.sql
-- Adds status column to user_feedback table

ALTER TABLE public.user_feedback
ADD COLUMN status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved'));

-- Policy to allow admins to UPDATE user_feedback so they can change the status
DROP POLICY IF EXISTS "user_feedback_update_admin_only" ON public.user_feedback;
CREATE POLICY "user_feedback_update_admin_only"
  ON public.user_feedback
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
