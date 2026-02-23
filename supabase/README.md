# Supabase setup (HerbaScan Personal Herbarium)

**Catalog rule (1-to-1):** The plant catalog is fixed and must mirror the ML model's output classes. Do not add or delete plants from the catalog via admin or API. Admin may only edit text fields (e.g. preparation, DOH info) for existing plants and review/approve/delete user-submitted scan images for dataset building. Adding a new plant requires a new model training and app release.

1. Create a project at [supabase.com](https://supabase.com). Note your project URL and anon key (Settings → API).
2. In the app, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (or edit `lib/core/config/supabase_config.dart`).
3. In Supabase Dashboard → SQL Editor, run the migration: `migrations/20260223000000_herbarium_schema.sql`.
4. In Dashboard → Storage, create a bucket named `herbarium-images` (public or private; if private, use RLS). Add policies:
   - **Insert**: Users can upload to their own folder: `(storage.foldername(name))[1] = auth.uid()::text` and `bucket_id = 'herbarium-images'`.
   - **Select**: Users can read own folder; admins can read all (see policy examples in the migration SQL comments).
   - **Delete**: Users can delete own files; admins can delete any.
5. To make your account admin: in SQL Editor run `UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';` (get your UUID from Auth → Users).

**Using Supabase CLI (recommended):** From project root, run once: `npx supabase login` (opens browser). Then: `npx supabase link --project-ref tsahfzmxqsgbxrrtbdnw` (use your project ref if different). Then: `npx supabase db push` to apply migrations. If prompted for database password, use the one from Supabase Dashboard → Project Settings → Database.
