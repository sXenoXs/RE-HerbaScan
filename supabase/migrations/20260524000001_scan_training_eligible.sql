-- Add training pipeline columns to public.scans.
-- Partial index covers the common admin query: plant_id WHERE training_eligible = true.

ALTER TABLE public.scans
  ADD COLUMN IF NOT EXISTS training_eligible boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS training_copied_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS idx_scans_training_eligible
  ON public.scans (plant_id, training_eligible)
  WHERE training_eligible = true;

-- ── Storage policies for training-datasets bucket ─────────────────────────────
-- Admin INSERT: needed so approveForTraining() can upload bytes from Flutter.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'storage'
       AND tablename  = 'objects'
       AND policyname = 'Admins upload training datasets'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "Admins upload training datasets"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (
          bucket_id = 'training-datasets'
          AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
        )
    $p$;
  END IF;
END;
$$;

-- Admin SELECT: needed so getTrainingEligibleScans() can list objects.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'storage'
       AND tablename  = 'objects'
       AND policyname = 'Admins read training datasets'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "Admins read training datasets"
        ON storage.objects FOR SELECT
        TO authenticated
        USING (
          bucket_id = 'training-datasets'
          AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
        )
    $p$;
  END IF;
END;
$$;
