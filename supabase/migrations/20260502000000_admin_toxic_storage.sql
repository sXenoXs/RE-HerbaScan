-- Allow admin users to upload, update, and delete images in the toxic-plants/ folder.
-- Run in Supabase Dashboard → SQL Editor (or npx supabase db push).

DROP POLICY IF EXISTS "Admins can manage toxic plant images in storage" ON storage.objects;
CREATE POLICY "Admins can manage toxic plant images in storage"
  ON storage.objects FOR ALL
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'toxic-plants'
    AND public.is_admin()
  )
  WITH CHECK (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'toxic-plants'
    AND public.is_admin()
  );

-- Allow public read of toxic-plant images (no auth required for viewing).
DROP POLICY IF EXISTS "Public read toxic plant images in storage" ON storage.objects;
CREATE POLICY "Public read toxic plant images in storage"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'toxic-plants'
  );
