-- Allow admins to delete feedback rows (for admin triage).
CREATE POLICY "user_feedback_delete_admin_only"
  ON public.user_feedback
  FOR DELETE
  USING (public.is_admin());
