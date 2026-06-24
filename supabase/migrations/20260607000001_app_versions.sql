-- =============================================================================
-- Migration: 20260607000001_app_versions.sql
-- HerbaScan OTA App Update System — app_versions table
-- Applied: June 07, 2026
-- =============================================================================
--
-- Creates the app_versions table used by OtaAppUpdateService to check for
-- new APK releases. On app launch (after splash), the service queries this
-- table and prompts users to update if a newer version is available.
--
-- Admin workflow to publish a new release:
--   1. flutter build apk --release --split-per-abi --dart-define=...
--   2. Upload app-arm64-v8a-release.apk → Supabase Storage → app-releases/android/
--   3. Copy the public URL from Storage
--   4. INSERT INTO app_versions (version_name, version_code, download_url,
--        release_notes, is_mandatory) VALUES ('1.0.27', 27, '<url>', 'Notes', false);
--   5. Users see update prompt on next app launch.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_versions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  version_name  TEXT        NOT NULL,                         -- e.g. "1.0.26"
  version_code  INT         NOT NULL,                         -- e.g. 26 (monotonically increasing)
  platform      TEXT        NOT NULL DEFAULT 'android'
                            CHECK (platform IN ('android', 'ios', 'web')),
  download_url  TEXT        NOT NULL,                         -- Supabase Storage public URL
  release_notes TEXT        DEFAULT '',
  is_mandatory  BOOLEAN     NOT NULL DEFAULT false,           -- true = forced update (cannot dismiss)
  is_active     BOOLEAN     NOT NULL DEFAULT true,            -- false = retracted / hidden
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Anyone (including anon) can read — app checks before login
CREATE POLICY "Anyone can read app_versions"
  ON public.app_versions
  FOR SELECT
  USING (true);

-- Only admins can publish new versions
CREATE POLICY "Admins can insert app_versions"
  ON public.app_versions
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update app_versions"
  ON public.app_versions
  FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "Admins can delete app_versions"
  ON public.app_versions
  FOR DELETE
  USING (public.is_admin());

-- Index for efficient latest-version lookup
CREATE INDEX IF NOT EXISTS idx_app_versions_platform_active
  ON public.app_versions (platform, is_active, version_code DESC);

-- Anon role: allow SELECT so OTA check works before user is logged in.
-- (RLS policy "Anyone can read app_versions" handles the row-level gate;
-- this table-level GRANT lets the anon role reach the gate.)
GRANT SELECT ON TABLE public.app_versions TO anon;
