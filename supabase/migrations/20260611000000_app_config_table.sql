-- =============================================================================
-- Migration: 20260611000000_app_config_table.sql
-- HerbaScan App Configuration — remote key-value store for admin-editable settings
-- Applied: June 11, 2026
-- =============================================================================
--
-- Central configuration table so admins can update app version, model version,
-- and help/tutorial content without shipping a new APK. The Flutter app reads
-- this table via AppConfigService on launch and after login.
--
-- Keys:
--   app_version    — e.g. "v1.0.28"
--   model_version  — e.g. "CNN v1.1"
--   help_content   — JSON blob with tips, issues, features, ood_explanation sections
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_config (
  key         TEXT        PRIMARY KEY,
  value       TEXT        NOT NULL,                              -- stored as text (JSON-encode complex values)
  description TEXT        DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID        REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Enable RLS
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Anyone can read config (needed before login for app version display)
CREATE POLICY "Anyone can read app_config"
  ON public.app_config
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "Admins can insert app_config"
  ON public.app_config
  FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update app_config"
  ON public.app_config
  FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "Admins can delete app_config"
  ON public.app_config
  FOR DELETE
  USING (public.is_admin());

-- Allow anon read
GRANT SELECT ON TABLE public.app_config TO anon;

-- Seed with current defaults so the app works before admin edits
INSERT INTO public.app_config (key, value, description) VALUES
  ('app_version', 'v1.0.26', 'Current app version displayed in Settings → Support & About'),
  ('model_version', 'CNN v1.0', 'Current ML model version displayed in Settings → Support & About'),
  ('help_content', '{"tips":[{"title":"Use a plain background","body":"Place the leaf on a plain white or light-colored background for the best results. Avoid busy patterns or shadows."},{"title":"Good lighting is key","body":"Natural daylight works best. Avoid harsh shadows or direct flash which can wash out leaf details."},{"title":"One leaf at a time","body":"Scan a single leaf per photo. Multiple leaves or overlapping foliage can confuse the AI."},{"title":"Hold steady","body":"Keep your hand steady or rest the phone on a surface to avoid motion blur."}],"issues":[{"title":"Blurry photo warning","body":"If your photo is too blurry, the app will warn you. Try holding your phone steadier or tapping the screen to refocus."},{"title":"Too dark warning","body":"If the image is too dark, move to a brighter area or turn on more lights. Natural daylight gives the best results."},{"title":"Edge detection failed","body":"The app looks for clear leaf edges. Make sure the leaf is fully visible and not cut off by the frame edges."},{"title":"AI confidence too low","body":"If the AI cannot confidently identify your plant, try a different angle, better lighting, or make sure the leaf is not damaged or curled."}],"features":[{"title":"AI Plant Identification","body":"Our AI model identifies 29 medicinal plants using a lightweight neural network that runs entirely on your device — no internet needed."},{"title":"Offline Mode","body":"Scan plants anywhere, even without internet. All AI processing happens on your phone using the TFLite model."},{"title":"Personal Herbarium","body":"Sign in to back up your scans to the cloud. Your herbarium syncs across devices and helps improve the AI for everyone."},{"title":"DOH-Approved Plants","body":"Browse the Department of Health\\u2019s officially endorsed medicinal plants with detailed usage guides and preparation instructions."},{"title":"Toxic Plant Warnings","body":"Learn to identify harmful plants with detailed toxin information, symptoms, and first-aid guidance."},{"title":"Health Condition Search","body":"Search medicinal plants by health condition or symptom to find natural remedies approved by DOH."}],"ood_explanation":"Our AI uses a confidence threshold to ensure only reliable identifications are shown. If the model is not confident enough (below 85%), the result is marked as \\u201cUnknown Plant\\u201d rather than risking a wrong identification. This protects you from misidentifying plants that look similar to the trained species. The model was trained on 29 medicinal plant species commonly found in the Philippines using MobileNetV2 architecture. It can distinguish these plants from others, but cannot identify plants outside its training set."}', 'Help & Tutorial content — JSON with tips, issues, features, ood_explanation')
ON CONFLICT (key) DO NOTHING;
