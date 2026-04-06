-- User feedback table for Option B: store feedback in Supabase for admin view.
-- Anonymous and authenticated users can submit; only admins can read.

CREATE TABLE IF NOT EXISTS public.user_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  rating INT NOT NULL,
  category TEXT NOT NULL,
  comment TEXT NOT NULL,
  feature_suggestion TEXT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_feedback_created_at
  ON public.user_feedback (created_at DESC);

ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;

-- INSERT: allow anyone (anonymous and authenticated) so milestone and Plant Result feedback work without login.
CREATE POLICY "user_feedback_insert_allow_all"
  ON public.user_feedback
  FOR INSERT
  WITH CHECK (true);

-- SELECT: only admins (via existing is_admin() SECURITY DEFINER).
CREATE POLICY "user_feedback_select_admin_only"
  ON public.user_feedback
  FOR SELECT
  USING (public.is_admin());
