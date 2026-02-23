# Supabase setup (HerbaScan Personal Herbarium)

**Catalog rule (1-to-1):** The plant catalog is fixed and must mirror the ML model's output classes. Do not add or delete plants from the catalog via admin or API. Admin may only edit text fields (e.g. preparation, DOH info) for existing plants and review/approve/delete user-submitted scan images for dataset building. Adding a new plant requires a new model training and app release.

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

**Confirm your signup** – In **Authentication → Emails → Templates → Confirm sign up**, you can keep the link-only body or add the code so users can enter it if you ever use confirm email:

```html
<h2>Confirm your signup</h2>

<p>Follow this link to confirm your user:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm your mail</a></p>

<p>Or enter this code in the app:</p>
<p><strong>{{ .Token }}</strong></p>
```

We recommend leaving **Confirm email** disabled so signup does not require the link; then this template is not used.

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

**Recommended:** Do **not** set `SUPABASE_JWT_SECRET` on Railway. Then `POST /identify` works for everyone (anonymous and logged-in users). Scans use online Grad-CAM; cloud save to Personal Herbarium remains opt-in when the user is signed in. No 401 errors.

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

## Step-by-step: Run the migration (Dashboard method)

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

**If you get an error**
- If it says something like “relation already exists”, you may have run the migration before. That’s okay; the script uses `CREATE TABLE IF NOT EXISTS` so it’s safe to run again in most cases.
- If the error is about a trigger or policy already existing, you can drop it first in a new query (e.g. `DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;`) then run the migration again, or ask for help with the exact error message.

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

**Step 4 – Save**
- Create each policy and save. After that, the app can upload to `herbarium-images/{user_id}/{scan_id}.jpg` and RLS will enforce access.

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

**Using Supabase CLI (recommended):** From project root, run once: `npx supabase login` (opens browser). Then: `npx supabase link --project-ref tsahfzmxqsgbxrrtbdnw` (use your project ref if different). Then: `npx supabase db push` to apply migrations. If prompted for database password, use the one from Supabase Dashboard → Project Settings → Database.
