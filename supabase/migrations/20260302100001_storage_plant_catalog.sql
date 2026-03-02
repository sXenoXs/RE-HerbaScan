-- Plant catalog images: admin uploads to herbarium-images/plant-catalog/{plant_id}.jpg
-- Public read so app can show images without auth (CachedNetworkImage).

-- Admin can upload to plant-catalog folder
DROP POLICY IF EXISTS "Admins can upload plant-catalog images" ON storage.objects;
CREATE POLICY "Admins can upload plant-catalog images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'plant-catalog'
    AND public.is_admin()
  );

-- Public read for plant-catalog (so image_url works in app)
DROP POLICY IF EXISTS "Public can read plant-catalog images" ON storage.objects;
CREATE POLICY "Public can read plant-catalog images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'plant-catalog'
  );

-- Admin can update/delete plant-catalog files
DROP POLICY IF EXISTS "Admins can update plant-catalog images" ON storage.objects;
CREATE POLICY "Admins can update plant-catalog images"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'plant-catalog'
    AND public.is_admin()
  )
  WITH CHECK (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'plant-catalog'
  );

DROP POLICY IF EXISTS "Admins can delete plant-catalog images" ON storage.objects;
CREATE POLICY "Admins can delete plant-catalog images"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'herbarium-images'
    AND (storage.foldername(name))[1] = 'plant-catalog'
    AND public.is_admin()
  );
