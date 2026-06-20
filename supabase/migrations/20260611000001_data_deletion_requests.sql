-- =============================================================================
-- Migration: 20260611000001_data_deletion_requests.sql
-- HerbaScan Data Deletion Requests — user-requested account data purging
-- Applied: June 11, 2026
-- =============================================================================
--
-- Users can request deletion of their cloud data (scans, profile) without
-- deleting their account. Admins manually review and approve/reject requests.
--
-- Workflow:
--   1. User taps "Request Data Deletion" in Settings (only when signed in)
--   2. Row inserted with status='pending'
--   3. Admin reviews in Admin Console → Data Deletion panel
--   4. Admin approves (data purged) or rejects (request closed)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.data_deletion_requests (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      TEXT        DEFAULT '',
  status      TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.data_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Users can read their own requests
CREATE POLICY "Users can read own deletion requests"
  ON public.data_deletion_requests
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own requests
CREATE POLICY "Users can insert own deletion requests"
  ON public.data_deletion_requests
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own pending requests (e.g. cancel)
CREATE POLICY "Users can update own pending requests"
  ON public.data_deletion_requests
  FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending');

-- Admins can read all requests
CREATE POLICY "Admins can read all deletion requests"
  ON public.data_deletion_requests
  FOR SELECT
  USING (public.is_admin());

-- Admins can update any request (approve/reject)
CREATE POLICY "Admins can update deletion requests"
  ON public.data_deletion_requests
  FOR UPDATE
  USING (public.is_admin());

-- Index for admin queries
CREATE INDEX IF NOT EXISTS idx_data_deletion_requests_status
  ON public.data_deletion_requests (status, created_at DESC);
