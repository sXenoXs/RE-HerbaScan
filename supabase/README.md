# Supabase setup (HerbaScan Personal Herbarium)

**Catalog rule:** The Supabase catalog has **30 rows**: 29 ML-mapped plant classes (matching the 31-class TFLite model's output classes exactly, excluding `Not_Plant` and `UnknownPlant`) plus Yerba Buena as a browse-only DOH-approved plant with no TFLite class yet. The 29 ML-mapped plants are fixed — do not add or delete them via admin or API. Adding a new ML class requires a retraining run, a new TFLite model, and an app release. Yerba Buena is the exception: it was inserted via migration `20260525000000_readd_yerba_buena_browse_only.sql` as a browse-only DOH reference and will not appear as a scan result. Admins may edit text fields (preparation, DOH info) for any catalog plant and review/approve/delete user-submitted scan images for ML dataset building.

1. Create a project at [supabase.com](https://supabase.com). Note your project URL and anon key (Settings → API).
2. In the app, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (or edit `lib/core/config/supabase_config.dart`).
3. **(Recommended)** Do not set `SUPABASE_JWT_SECRET` on Railway so /identify works for all users. If you set it and get 401 when scanning, remove it (see [Step 3: Railway JWT](#step-3-railway--jwt-for-identify-optional-recommend-leaving-unset)).
4. To see **Review submissions** in the app and use the admin dashboard: make your account admin (see [Step 4: Make your account admin](#step-4-make-your-account-admin) below).
5. **(Recommended for mobile)** Disable “Confirm email” so users can sign in right after signup without clicking an email link (see [Email confirmation (Confirm your signup)](#email-confirmation-confirm-your-signup) below).
6. **(Recommended, Pro plan)** Enable Leaked Password Protection so Supabase blocks compromised passwords (see [Security: Leaked Password Protection](#security-leaked-password-protection-recommended) below).

---

## Site URL and Redirect URLs (fix)

In **Authentication → URL Configuration**: (1) **Site URL** – Set to **`herbascan://auth/callback`** and click Save changes. (2) **Redirect URLs** – If it says "No Redirect URLs", click **Add URL**, add **`herbascan://auth/callback`** (or **`herbascan://*`**), save. Both are required so link-based auth opens the app.

---

## Email confirmation (Confirm your signup)

If you see **“Email link is invalid or has expired”** or a redirect to **localhost:3000** when you click “Confirm your mail” in the Supabase signup email, two things are going on:

1. **Wrong redirect URL** – Supabase is set to send users to `http://localhost:3000` after they click the link. HerbaScan is a **mobile app**, not a website. Nothing runs on localhost on the phone, so the link can’t complete and you may see “This site can’t be reached” or “localhost refused to connect”.
2. **Link expiry** – Confirmation links expire (often after 1 hour). If you click the link late, you get `otp_expired` / “Email link is invalid or has expired”.

**Recommended fix: turn off email confirmation** so users can sign in immediately after signup (no email link needed).

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **Authentication** → **Providers**.
3. Click **Email**.
4. Turn **off** “Confirm email” (disable the option that requires users to confirm their email before signing in).
5. Save.

After this, new signups can sign in right away without clicking a link. No redirect or localhost is involved.

**If you already signed up and the link expired**

- Try **Sign in** in the app with the same email and password. Some setups allow sign-in before confirmation.
- If sign-in still says the user must confirm: in Supabase go to **Authentication** → **Users**, find the user, delete it, then sign up again in the app (with “Confirm email” off, the new account will work without a link).

**Do I need to customize the email templates for “otp_expired” or “link already used”?**  
No. Those messages are shown on Supabase’s page after the user clicks the link, not in the email body. The **Emails → Templates** options (Confirm sign up, Magic link, Reset password, etc.) only change the email content (subject, body, link). If you keep “Confirm email” off (recommended for this app), confirmation emails are not sent. If you later re-enable it, you can optionally edit **Confirm sign up** to add friendlier wording (e.g. “Confirm within 1 hour”).

---

## Password reset and change-email links (localhost / “This site can’t be reached”)

If you tap the link in the **Reset password** or **Change email** email and see **localhost:3000** or **“This site can’t be reached”**, the cause is the same as for signup confirmation: Supabase is redirecting to a **web** URL (the default **Site URL** or **Redirect URL**), but HerbaScan is a **mobile app**. There is no server on the phone, so the link fails.

**What to do**

1. **Set a redirect URL the app can open (app link)**  
   In Supabase: **Authentication** → **URL Configuration** (or **Providers** → **Email** → redirect settings).  
   - Set **Site URL** to something that won’t be used for these links (e.g. keep as is or use `https://yourapp.com` if you have one).  
   - Under **Redirect URLs**, add: **`herbascan://auth/callback`** (this is the scheme the app uses).  
   Save.

2. **Use “Forgot password?” in the app**  
   The app sends the reset email with `redirectTo: herbascan://auth/callback`. After you add that URL in Supabase, the link in the email will open HerbaScan (on the same device) instead of a browser to localhost. The app will then handle the link and let you set a new password inside the app.

3. **If you still open the link on a computer**  
   The link will go to localhost there and show an error. Either open the same link on the **phone** where HerbaScan is installed, or request a new reset email and tap the new link on the phone.

**Change email** works the same way: the confirmation link uses the same redirect. Add **`herbascan://auth/callback`** to Redirect URLs so the link can open the app.

**Why redirect still goes to localhost:** Supabase **strips** `redirectTo` and falls back to **Site URL** if the URL is **not in the Redirect URLs whitelist**. So you must add `herbascan://auth/callback` (or `herbascan://*`) under **Authentication → URL Configuration → Redirect URLs**. Until it is listed there, the app’s `redirectTo` is ignored.

**Why you get otp_expired on first tap:** Email clients and security scanners often **pre-fetch links**, consuming Supabase’s **single-use** token before you tap. A bulletproof alternative is **6-digit OTP**: show **Your code: {{ .Token }}** in the email template and have the user enter the code in the app, then call **verifyOtp** with type recovery. See Supabase template docs for the exact variable names.

---

## Password reset with 6-digit OTP (bulletproof)

To avoid link scanners consuming the token and redirect configuration issues, use a **6-digit code** in the email and a screen in the app where the user enters it.

1. **Supabase:** **Authentication → Emails → Templates** → edit **Reset password**. Use or add **Your code: {{ .Token }}** (or the variable your Supabase version uses; check template docs) so the user gets a typeable code instead of only a link.
2. **Flutter:** After the user receives the email, show a screen for the **6-digit code**, then call Supabase **verifyOtp** with `type: OtpType.recovery` and the code to establish the session, then navigate to the “Set new password” screen.

Scanners cannot consume a code; redirect URL is not required for this flow. **HerbaScan now implements this:** after "Check your email" the user can tap **Enter 6-digit code**, type the code from the email, then set a new password.

**Copy-paste template bodies**

**Reset password** – In **Authentication → Emails → Templates → Reset password**, set the **Body** (Source) to:

```html
<h2>Reset Password</h2>

<p>Follow this link to reset the password for your user:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>

<p>Or enter this 6-digit code in the HerbaScan app:</p>
<p><strong>{{ .Token }}</strong></p>
```

Save. Users can either tap the link (if Redirect URLs are set) or tap **Enter 6-digit code** in the app and type the code from the email.

**Confirm your signup** – If **Confirm email** is **enabled**, new users must confirm before signing in. HerbaScan supports a **6-digit code** flow: after signup the app shows **Enter the code from your email**; the user enters the code and the account is activated. To support this, edit **Authentication → Emails → Templates → Confirm sign up** and include the token in the body, for example:

```html
<h2>Confirm your signup</h2>

<p>Follow this link to confirm your user:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm your mail</a></p>

<p>Or enter this 6-digit code in the HerbaScan app:</p>
<p><strong>{{ .Token }}</strong></p>
```

If **Confirm email** is **disabled**, users can sign in right after signup and this template is not used.

---

## Auth email rate limits

When using Supabase’s **built-in email** (no custom SMTP), auth endpoints that send email (signup, password reset, etc.) are limited to **2 emails per hour** in total. If you see “email rate limit exceeded” or a 429 error in the app, that limit was hit. The app shows a friendly message: *“Too many signup emails sent. Please try again in about an hour.”*  

To raise the limit, use a **custom SMTP** provider (e.g. SendGrid, AWS SES). See [Production checklist – Auth rate limits](https://supabase.com/docs/guides/deployment/going-into-prod#auth-rate-limits) and the “Built-in email service and custom SMTP” section below.

---

## Built-in email service and custom SMTP (warning in dashboard)

Supabase may show: **“Set up custom SMTP – You’re using the built-in email service. This service has rate limits and is not meant to be used for production apps.”**

- **For development or thesis:** The built-in service is fine. You can ignore the warning or dismiss it. Rate limits are usually enough for a few users and testing.
- **For production (many users):** Set up **custom SMTP** so Supabase sends mail through your own provider (e.g. SendGrid, Mailgun, AWS SES, or your domain’s SMTP).  
  In the dashboard: **Authentication** → **Emails** → **SMTP Settings** → enable **Custom SMTP** and enter your SMTP host, port, user, and password. Then save. No code changes are required in HerbaScan.

---

## Security: Leaked Password Protection (recommended)

Supabase can block **compromised passwords** by checking new passwords against [HaveIBeenPwned.org](https://haveibeenpwned.com/Passwords). Enabling this reduces credential-stuffing risk.

**Step-by-step**

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **Authentication** → **Providers**.
3. Click **Email**.
4. Scroll to the **Password** / security section (password requirements, leaked password check).
5. Turn **on** the option for **Leaked password protection** (or “Prevent use of leaked passwords” / “Check against HaveIBeenPwned”).
6. Save.

**Note:** This feature is available on the **Pro plan and above**. If you don’t see it, you’re likely on the Free plan; you can upgrade or leave it off. Existing users keep signing in; they only get a `WeakPasswordError` if they try to *change* to a leaked password.

---

## Step 3: Railway – JWT for /identify (optional; recommend leaving unset)

**Recommended:** Do **not** set `SUPABASE_JWT_SECRET` on Railway. Then `POST /identify` works for everyone (anonymous and logged-in users). Cloud save to Personal Herbarium remains opt-in when the user is signed in. No 401 errors.

**If you get 401 "Invalid or expired token":** Remove the variable. In Railway → your backend service → **Variables** → delete `SUPABASE_JWT_SECRET` → Save. Railway will redeploy; after that, /identify will accept all requests.

**Optional – require sign-in for /identify:** If you want only signed-in users to call the plant-identification API, set `SUPABASE_JWT_SECRET` on Railway to your Supabase **JWT Secret** (Project Settings → API → JWT Settings → JWT Secret). The value must match exactly; any typo or wrong project causes "Invalid or expired token" even when the user is logged in. If you see 401 when logged in, the secret is wrong – remove the variable to allow all requests again.

**If you do set it:** Get the JWT secret from [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Project Settings** → **API** → **JWT Settings** → **JWT Secret**. In Railway → backend service → **Variables** → add `SUPABASE_JWT_SECRET` with that value. Save (Railway redeploys).

<!-- legacy steps kept for reference
1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **Project Settings** (gear in sidebar) → **API**.
3. Under **JWT Settings**, find **JWT Secret** (long string). Copy it (use “Reveal” if it’s masked).

**Where to set it on Railway**

1. Open [Railway Dashboard](https://railway.app/dashboard) and select your project.
2. Click the **HerbaScan backend service** (the one that runs `backend/`).
3. Open the **Variables** tab.
4. Click **New Variable** (or **Add Variable**).
5. **Variable name:** `SUPABASE_JWT_SECRET`  
   **Value:** paste the JWT secret from Supabase (no quotes).
6. Save. Railway will redeploy...
-->

---

## Complete Migrations Reference (all 19)

Apply all migrations in a single command using the Supabase CLI (recommended):

```bash
npx supabase login
npx supabase link --project-ref tsahfzmxqsgbxrrtbdnw
npx supabase db push
```

The table below documents every migration file in `supabase/migrations/` in chronological order. All 19 are currently applied to the production project (`tsahfzmxqsgbxrrtbdnw`).

| Migration file | Purpose |
| --- | --- |
| `20260223000000_herbarium_schema.sql` | `profiles` + `scans` tables; `on_auth_user_created` trigger |
| `20260228000000_profiles_admin_and_email.sql` | `is_active`, `email` columns on `profiles`; admin list/deactivate policies |
| `20260228000001_plant_metadata.sql` | `plant_metadata` table |
| `20260301000000_fix_profiles_rls_recursion.sql` | `is_admin()` SECURITY DEFINER function |
| `20260302000000_storage_herbarium_policies.sql` | `herbarium-images` bucket RLS policies (INSERT/SELECT/DELETE) |
| `20260302100000_catalog_plants_schema.sql` | Full plant catalog schema — 8 tables: `catalog_plants`, `catalog_medicinal_uses`, `catalog_preparation_methods`, `catalog_safety`, `catalog_habitat`, `catalog_conditions`, `catalog_condition_plants`, `catalog_plant_anatomy` |
| `20260302100001_storage_plant_catalog.sql` | Plant catalog storage bucket |
| `20260302200000_catalog_plant_anatomy.sql` | `catalog_plant_anatomy` table refinements |
| `20260314000000_catalog_safety_strict_contraindications.sql` | `needs_strict_contraindications` BOOLEAN (default false) on `catalog_safety`; backfills `true` for Kamias, Kamoteng Kahoy, Kakawate |
| `20260316000000_user_feedback.sql` | `public.user_feedback` table + RLS (INSERT open to all; SELECT admin-only) |
| `20260316000001_user_feedback_admin_delete.sql` | Admin DELETE policy on `user_feedback` |
| `20260425000000_toxic_plant_images.sql` | Toxic plant image storage bucket and initial policies |
| `20260502000000_admin_toxic_storage.sql` | Admin-only upload and management policies for toxic plant image storage |
| `20260523000000_reduce_catalog_to_31_classes.sql` | Deleted 13 non-model plant rows from all 8 catalog tables (child-first order); catalog reduced 42 → 29 rows; `DROP COLUMN IF EXISTS ai_vision_summary` guard |
| `20260524000000_model_versions_rls.sql` | RLS enabled on `public.model_versions`; SELECT open to all; INSERT/UPDATE/DELETE restricted to `is_admin()` |
| `20260524000001_scan_training_eligible.sql` | `training_eligible boolean NOT NULL DEFAULT false` + `training_copied_at timestamptz NULL` on `public.scans`; partial index; `training-datasets` bucket admin INSERT/SELECT policies |
| `20260525000000_readd_yerba_buena_browse_only.sql` | Yerba Buena (*Clinopodium douglasii*) re-inserted across all 8 catalog tables as browse-only DOH plant; `SELECT COUNT(*) FROM catalog_plants` = **30** |

---

## Step-by-step: Run the migration (Dashboard method)

> **Recommended:** Use the CLI (`npx supabase db push`) to apply all 19 migrations at once. The dashboard method below is for reference when you need to inspect or manually apply a single migration.

This runs your `20260223000000_herbarium_schema.sql` file in Supabase **without** using the CLI.

**Step 1 – Open your project**
- Go to [https://supabase.com/dashboard](https://supabase.com/dashboard) and sign in.
- Click your project (e.g. the one with URL `https://tsahfzmxqsgbxrrtbdnw.supabase.co`).

**Step 2 – Open the SQL Editor**
- In the left sidebar, click **SQL Editor**.

**Step 3 – New query**
- Click **+ New query** (or “New query”) so you have an empty SQL editor.

**Step 4 – Paste the migration**
- Open this file in your code editor: `supabase/migrations/20260223000000_herbarium_schema.sql`.
- Select all (Ctrl+A), copy (Ctrl+C).
- Paste into the Supabase SQL Editor (Ctrl+V).

**Step 5 – Run it**
- Click **Run** (or press Ctrl+Enter).
- Wait a few seconds. You should see “Success. No rows returned” (or similar). That means the tables `profiles` and `scans` and all policies were created.

**Step 6 – Check tables (optional)**
- In the left sidebar, open **Table Editor**.
- You should see `profiles` and `scans` under the `public` schema. You can open them to see the columns (no data yet).

### Step 6b – Admin user management (optional)

Run `supabase/migrations/20260228000000_profiles_admin_and_email.sql` in the SQL Editor to add `is_active` and `email` to `profiles`, backfill email, and add admin policies for listing and deactivating users. Required for the Admin Web Portal **User Management** module.

### Step 6c – Strict contraindication flagging (optional) *(v0.9.4 – March 10, 2026)*

Run `supabase/migrations/20260314000000_catalog_safety_strict_contraindications.sql` in the SQL Editor to add column `needs_strict_contraindications` (BOOLEAN, default false) to `catalog_safety`. The migration backfills `true` for Kamias, Kamoteng Kahoy, and Kakawate. The Flutter app uses this to show a prominent “Use with strict caution” card; local SQLite is upgraded to version 8 with the same column in `safety_profiles`.

### Step 6d – User feedback table (optional) *(v0.9.4 – March 10, 2026)*

Run `supabase/migrations/20260316000000_user_feedback.sql` in the SQL Editor to create `public.user_feedback` and RLS (INSERT allowed for all, SELECT for admins only). Required for the Admin **Feedback** tab.

Schema — table `public.user_feedback`: `id` (UUID PK), `user_id` (UUID NULL, references auth.users), `rating`, `category`, `comment`, `feature_suggestion`, `metadata` (JSONB), `created_at`. Index on `created_at DESC` for admin list ordering. RLS policies: `user_feedback_insert_allow_all` (INSERT with check true), `user_feedback_select_admin_only` (SELECT using `public.is_admin()`).

### Step 6e – Admin delete feedback (optional) *(v0.9.5 – March 16, 2026)*

Run `supabase/migrations/20260316000001_user_feedback_admin_delete.sql` in the SQL Editor (or `npx supabase db push`) to add RLS policy `user_feedback_delete_admin_only` (DELETE using `public.is_admin()`) so admins can delete feedback rows from the Admin Feedback tab. Requires Step 6d first.

### Step 6f – Catalog 42 → 29 alignment *(v1.0.8 – May 23, 2026)*

Run `supabase/migrations/20260523000000_reduce_catalog_to_31_classes.sql` (or `npx supabase db push`). Deletes 13 plant rows not present in the 31-class TFLite model from all 8 catalog tables in child-first order. Post-migration: `SELECT COUNT(*) FROM catalog_plants` = **29**. Includes a `DROP COLUMN IF EXISTS ai_vision_summary` guard on both `catalog_plants` and `plant_metadata` (idempotent). **Already applied to production.**

### Step 6g – model\_versions RLS *(v1.0.9 – May 24, 2026)*

Run `supabase/migrations/20260524000000_model_versions_rls.sql` (or `npx supabase db push`). Enables Row Level Security on `public.model_versions` (previously unprotected — flagged Critical by Supabase Advisor). Adds 4 policies: `SELECT` open to all (required by `OtaModelService` for non-admin OTA model update checks); `INSERT`, `UPDATE`, `DELETE` restricted to admins via `public.is_admin()`. No app code changes needed. **Already applied to production.**

### Step 6h – Training-eligible scans pipeline *(v1.0.12 – May 24, 2026)*

Run `supabase/migrations/20260524000001_scan_training_eligible.sql` (or `npx supabase db push`). Adds schema support for the approved-image-to-training-dataset pipeline:

- `training_eligible boolean NOT NULL DEFAULT false` column on `public.scans`
- `training_copied_at timestamptz NULL` column on `public.scans`
- Partial index: `idx_scans_training_eligible ON scans(plant_id, training_eligible) WHERE training_eligible = true`
- Two idempotent storage policies on `storage.objects` for the `training-datasets` bucket: admin INSERT and admin SELECT

Required for Admin → Submission Triage → “Approve + Add to Training Data” and the Training Images sheet approved-scan count. **Already applied to production.**

> **CLI history repair (v1.0.12):** Five migrations applied manually via the Dashboard (from `20260316000001` through `20260524000000`) were not registered in the Supabase CLI migration history. They were backfilled as `applied` in v1.0.12 so `npx supabase db push` correctly skips them. If you encounter them reported as pending, run `supabase migration repair --status applied <timestamp>` for each affected file.

### Step 6i – Yerba Buena browse-only plant *(v1.0.22 – May 25, 2026)*

Run `supabase/migrations/20260525000000_readd_yerba_buena_browse_only.sql` (or `npx supabase db push`). Idempotent migration using `ON CONFLICT DO NOTHING` and `WHERE NOT EXISTS` guards throughout. Re-inserts Yerba Buena (*Clinopodium douglasii*, `id: yerba-buena-001`) across all 8 catalog tables:

- `catalog_plants` — browse-only DOH plant, no `model_class` assigned
- `catalog_medicinal_uses` — 5 conditions: Headache, Toothache, Arthritis/Rheumatism, Nausea, Cough/Colds
- `catalog_preparation_methods` — Mint Tea decoction + Topical Compress
- `catalog_safety` — `pregnancy_warning: true` (emmenagogue risk at high doses)
- `catalog_habitat` — Cordillera/Tagaytay/Benguet/Mountain Province + cultivated
- `catalog_conditions` — 5 new conditions (`ON CONFLICT (name) DO NOTHING`)
- `catalog_condition_plants` — links all 5 conditions
- `catalog_plant_anatomy` — leaves part (`WHERE NOT EXISTS` guard)

Post-migration: `SELECT COUNT(*) FROM catalog_plants` = **30**. **Already applied to production.**

### If you get an error

If it says something like “relation already exists”, you may have run the migration before. The scripts use `CREATE TABLE IF NOT EXISTS` so it is safe to run again in most cases. If the error is about a trigger or policy already existing, drop it first in a new query (e.g. `DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;`) then run the migration again.

---

**After the migration:** Continue with the Storage bucket steps below.

---

## Where to find Storage in Supabase

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard) and open your project.
2. In the **left sidebar**, click **Storage** (under “Build” or in the main menu with Database, Auth, etc.).
3. You’ll see the Storage page with any existing buckets. Use it to create the bucket and add policies.

---

## Step-by-step: Create the `herbarium-images` bucket and policies

**Step 1 – Open Storage**
- Dashboard → left sidebar → **Storage**.

**Step 2 – Create the bucket**
- Click **New bucket**.
- **Name:** `herbarium-images` (must match exactly; the app uses this name).
- **Public bucket:** Turn **on** if you want image URLs to be directly viewable; turn **off** for private (app still works with RLS).
- Click **Create bucket**.

**Step 3 – Add policies**
- Click the bucket name **herbarium-images**, then open the **Policies** tab (or click **New policy** from the Storage overview).
- Add these three policies (use “For full customization” or “New policy” and paste the expression):

| Policy name              | Allowed operation | Target roles | WITH CHECK (INSERT) or USING (SELECT/DELETE) |
|--------------------------|-------------------|--------------|-----------------------------------------------|
| Users upload own folder  | INSERT            | authenticated| `bucket_id = 'herbarium-images' AND (storage.foldername(name))[1] = auth.uid()::text` |
| Users read own folder   | SELECT            | authenticated| `bucket_id = 'herbarium-images' AND (storage.foldername(name))[1] = auth.uid()::text` |
| Admins read all         | SELECT            | authenticated| `bucket_id = 'herbarium-images' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')` |
| Users delete own folder | DELETE            | authenticated| `bucket_id = 'herbarium-images' AND (storage.foldername(name))[1] = auth.uid()::text` |
| Admins delete any       | DELETE            | authenticated| `bucket_id = 'herbarium-images' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')` |

**Using the policy editor (per policy):**
- **Insert:** Policy name e.g. “Users upload own folder”. Operation: **Insert**. WITH CHECK expression:  
  `(storage.foldername(name))[1] = auth.uid()::text`
- **Select (users):** Operation **Select**. USING expression:  
  `(storage.foldername(name))[1] = auth.uid()::text`
- **Select (admins):** Operation **Select**. USING expression:  
  `EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')`
- **Delete (users):** Operation **Delete**. USING:  
  `(storage.foldername(name))[1] = auth.uid()::text`
- **Delete (admins):** Operation **Delete**. USING:  
  `EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')`

Ensure the bucket name in your policy is `herbarium-images` (the UI may add `bucket_id = 'herbarium-images'` for you when the policy is scoped to that bucket).

**Alternative: apply policies via SQL migration**
- If you see **403 "new row violates row-level security policy"** when saving to cloud, the bucket exists but storage RLS policies are missing. Run the migration **`supabase/migrations/20260302000000_storage_herbarium_policies.sql`** in Dashboard → SQL Editor (or run `npx supabase db push`). It creates INSERT, SELECT, UPDATE, and DELETE policies so authenticated users can upload to their own folder (`user_id/scan_id.jpg`). Create the bucket first (Step 2 above) if it does not exist.

**Step 4 – Save**

- Create each policy and save (or run the migration above). After that, the app can upload to `herbarium-images/{user_id}/{scan_id}.jpg` and RLS will enforce access.

---

## Step-by-step: Create the `training-datasets` bucket and policies *(v1.0.12 – May 24, 2026)*

The `training-datasets` bucket stores copies of approved scan images used for ML model retraining. It is **admin-only** — regular users cannot upload to or read from this bucket. Policies were added via migration `20260524000001_scan_training_eligible.sql`.

### Step 1 – Open Storage

- Dashboard → left sidebar → **Storage**.

### Step 2 – Create the bucket

- Click **New bucket**.
- **Name:** `training-datasets` (must match exactly).
- **Public bucket:** Leave **off** (private — admin-only access).
- Click **Create bucket**.

### Step 3 – Add policies

| Policy name | Allowed operation | Target roles | Expression |
| --- | --- | --- | --- |
| Admin insert training datasets | INSERT | authenticated | `bucket_id = 'training-datasets' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')` |
| Admin select training datasets | SELECT | authenticated | `bucket_id = 'training-datasets' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')` |

Alternative: run `supabase/migrations/20260524000001_scan_training_eligible.sql` in Dashboard → SQL Editor (or `npx supabase db push`). The migration creates both policies idempotently. Create the bucket first (Step 2 above) if it does not exist.

### Step 4 – Save

- After creating the policies, the Admin Portal → Submission Triage → "Approve + Add to Training Data" workflow can copy approved scans to `training-datasets/{plant_id}/{scan_id}.jpg`.

---

## Step 4: Make your account admin

To see **Review submissions** in Settings and open the admin dashboard (list all user submissions, Approve/Reject/Delete), your user must have `role = 'admin'` in `public.profiles`.

**Step 1 – Get your user UUID**

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. In the left sidebar, go to **Authentication** → **Users**.
3. Find your user (the email you use to sign in) and copy its **User UID** (e.g. `a1b2c3d4-e5f6-7890-abcd-ef1234567890`). That is your `YOUR_USER_UUID`.

**Step 2 – Run the update in SQL Editor**

1. In the left sidebar, click **SQL Editor**.
2. Click **+ New query**.
3. Paste this (replace the UUID with yours):

   ```sql
   UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';
   ```

   Example, if your UID is `a1b2c3d4-e5f6-7890-abcd-ef1234567890`:

   ```sql
   UPDATE public.profiles SET role = 'admin' WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
   ```

4. Click **Run** (or Ctrl+Enter). You should see “Success” and a row count (e.g. `1`).
5. Sign out and sign back in to the app (or restart it) so the app reloads your role. After that, **Review submissions** will appear in Settings and open the admin dashboard.

---

## Account deactivation (admin)

Admins can set `is_active = false` on a user’s row in `public.profiles`. When that user next opens the app or when their role is reloaded, the app signs them out and shows an alert: “Your account has been deactivated by an administrator.” They must contact an admin to be reactivated (`is_active = true`).

---

## Delete account (Edge Function)

The app’s **Settings → Account → Delete account** option calls the Supabase Edge Function **`delete-user`** so users can permanently delete their Personal Herbarium account. Supabase Auth does not allow client apps to delete users directly; the function uses the **service role** to perform the deletion.

**Deploy the function**

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli) and log in: `npx supabase login`.
2. Link the project (if not already): `npx supabase link --project-ref YOUR_PROJECT_REF`.
3. Deploy the function: `npx supabase functions deploy delete-user`.

The repo includes `supabase/config.toml` with `verify_jwt = false` for `delete-user`. That turns off the **gateway** JWT check (which can fail with Supabase’s new asymmetric signing). The function still **verifies the JWT inside** using the JWKS endpoint, so the endpoint remains protected.

The function lives in `supabase/functions/delete-user/index.ts`. (1) **Self-delete:** with no body, it deletes the authenticated user. (2) **Admin delete:** with body `{ "user_id": "<uuid>" }`, it verifies the caller is admin (via `profiles.role`), then deletes that user. The Flutter app deletes the user’s storage objects (herbarium-images) before invoking the function for admin delete.

**If the function is not deployed:** Tapping **Delete account** would previously show a raw 404. The app now shows a clear message that the function is not deployed and includes the deploy command: `npx supabase functions deploy delete-user`. Deploy as above to enable account deletion.

**Storage:** For self-delete, Supabase may block deletion until storage is removed. For admin delete, the app removes the user’s folder in `herbarium-images` before calling the function.

**401 Invalid JWT when deleting (self or admin):** The gateway can reject the request before it reaches the function. (1) Ensure `supabase/config.toml` has `[functions.delete-user]` with **`verify_jwt = false`** so the gateway does not validate the JWT; the function validates it internally via the JWKS endpoint (Supabase asymmetric signing). (2) Deploy to the **same project** as the app: `npx supabase link --project-ref YOUR_PROJECT_REF`, then `npx supabase functions deploy delete-user`. If you still see 401, redeploy so the config is applied; the function verifies the token with the project’s JWKS endpoint.

---

## Force activate email (Edge Function) *(introduced in v0.9.5 – March 16, 2026)*

Admins can **force-verify a user’s email** (set `email_confirmed_at`) from **Admin → User Management** via the **"Force activate email"** menu item. This lets users sign in without completing the email OTP/link flow. The app calls the Edge Function **`force-verify-user`**, which verifies the caller is admin (via `profiles.role`) and then uses the Auth Admin API to set the user’s email as confirmed.

**Deploy the function**

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli) and log in: `npx supabase login`.
2. Link the project (if not already): `npx supabase link --project-ref YOUR_PROJECT_REF`.
3. Deploy: `npx supabase functions deploy force-verify-user`.

Config in `supabase/config.toml`: `[functions.force-verify-user] verify_jwt = false` (same pattern as `delete-user`; the function verifies JWT via JWKS and checks admin role). If the function is not deployed, the app shows a SnackBar: *"Force verify is not available. Deploy the force-verify-user Edge Function."*

---

## Using Supabase CLI (recommended)

From project root, run once: `npx supabase login` (opens browser). Then: `npx supabase link --project-ref tsahfzmxqsgbxrrtbdnw` (use your project ref if different). Then: `npx supabase db push` to apply all **19 migrations** in order. If prompted for database password, use the one from Supabase Dashboard → Project Settings → Database.

All 19 migrations are already applied to production. If any are reported as pending after linking a fresh CLI, repair the history with:

```bash
supabase migration repair --status applied <timestamp>
```

Run this for each migration that was applied manually via the Dashboard (from `20260316000001_user_feedback_admin_delete.sql` through `20260524000000_model_versions_rls.sql`). See Step 6h above for details on the CLI history repair performed in v1.0.12.
