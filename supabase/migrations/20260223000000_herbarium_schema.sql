-- HerbaScan: Personal Herbarium schema (profiles, scans, storage, RLS)
-- Run this in Supabase Dashboard → SQL Editor. Replace if you already have profiles.

-- 1. Profiles: extend auth with role (user | admin). New signups default to 'user'.
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: users read/update own profile; service role can update any (for admin grant).
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile (non-role fields only in app; role changed via dashboard)"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Auto-create profile on signup (role = 'user').
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role)
  VALUES (NEW.id, 'user');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Scans (Personal Herbarium). plant_id = existing catalog id (1-to-1 with model classes).
CREATE TABLE IF NOT EXISTS public.scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plant_id TEXT,
  scan_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  image_url TEXT,
  confidence_score REAL,
  predictions JSONB,
  metadata JSONB DEFAULT '{}',
  gradcam_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scans_user_id ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_scan_date ON public.scans(scan_date DESC);
CREATE INDEX IF NOT EXISTS idx_scans_status ON public.scans(status);

ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

-- Users: CRUD own scans only.
CREATE POLICY "Users can insert own scans"
  ON public.scans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can select own scans"
  ON public.scans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own scans"
  ON public.scans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own scans"
  ON public.scans FOR DELETE
  USING (auth.uid() = user_id);

-- Admins: read all scans (for data collection review). Use service role or add admin policy.
CREATE POLICY "Admins can select all scans"
  ON public.scans FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update scan status"
  ON public.scans FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete any scan"
  ON public.scans FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- 3. Storage bucket: herbarium-images. Create in Dashboard → Storage → New bucket.
-- Then add policies (or run via SQL):
-- INSERT: auth.uid() = (storage.foldername(name))[1] (user can upload to own folder)
-- SELECT: own folder or admin
-- DELETE: own folder or admin

-- Note: Bucket and storage policies are often created in Dashboard. Example RLS for storage:
-- Policy "Users can upload to own folder" ON storage.objects FOR INSERT WITH CHECK (
--   bucket_id = 'herbarium-images' AND (storage.foldername(name))[1] = auth.uid()::text
-- );
-- Policy "Users can read own files" ON storage.objects FOR SELECT USING (
--   bucket_id = 'herbarium-images' AND (storage.foldername(name))[1] = auth.uid()::text
-- );
-- Policy "Admins can read all" ON storage.objects FOR SELECT USING (
--   bucket_id = 'herbarium-images' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
-- );
