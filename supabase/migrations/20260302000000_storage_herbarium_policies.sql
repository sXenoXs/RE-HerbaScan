-- Storage RLS for herbarium-images bucket
-- Fixes 403 "new row violates row-level security policy" when uploading from app.
-- Run in Supabase Dashboard → SQL Editor (or npx supabase db push).
-- Ensure the bucket "herbarium-images" exists (Dashboard → Storage → New bucket if needed).

-- Allow authenticated users to upload to their own folder: userId/scanId.jpg
DROP POLICY IF EXISTS "Users can upload to own herbarium folder" ON storage.objects;
CREATE POLICY "Users can upload to own herbarium folder"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to read their own files (for viewing in app)
DROP POLICY IF EXISTS "Users can read own herbarium files" ON storage.objects;
CREATE POLICY "Users can read own herbarium files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to update/upsert their own files (upsert: true in app)
DROP POLICY IF EXISTS "Users can update own herbarium files" ON storage.objects;
CREATE POLICY "Users can update own herbarium files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to delete their own files
DROP POLICY IF EXISTS "Users can delete own herbarium files" ON storage.objects;
CREATE POLICY "Users can delete own herbarium files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
