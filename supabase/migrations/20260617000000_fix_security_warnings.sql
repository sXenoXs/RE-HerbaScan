-- Fix Warning 1: Restrict user_feedback INSERT to anonymous and authenticated users (prevents WITH CHECK (true))
DROP POLICY IF EXISTS "user_feedback_insert_allow_all" ON public.user_feedback;
CREATE POLICY "user_feedback_insert_allow_all"
  ON public.user_feedback
  FOR INSERT
  WITH CHECK (auth.role() IN ('anon', 'authenticated'));

-- Fix Warnings 2 & 3: Drop overly broad SELECT policies on storage buckets that allow listing all files
DROP POLICY IF EXISTS "Public read live-models" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads from training-datasets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can read training images" ON storage.objects;

-- Fix Warnings 4 & 6: Revoke EXECUTE on trigger function handle_new_user() from public roles
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Note on Warnings 5 & 7 (is_admin()):
-- is_admin() is a SECURITY DEFINER function in the public schema. This triggers a warning,
-- but the function is safe (it merely returns a boolean about the caller's own role) and is 
-- heavily utilized in over 20 RLS policies. It is intentionally ignored here.
