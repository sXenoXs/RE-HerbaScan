# Supabase Setup

This document provides the necessary commands and configuration details for managing the HerbaScan Supabase backend.

## 1. Quick Start (Applying Migrations)

HerbaScan relies on 24 SQL migrations to provision its database schema, Row Level Security (RLS) policies, and Storage buckets. Apply them all at once using the Supabase CLI.

```bash
# 1. Login and link your project
npx supabase login
npx supabase link --project-ref <YOUR_PROJECT_REF>

# 2. Push all migrations to production
npx supabase db push
```

**What this does:**
- Provisions the entire 8-table Plant Catalog schema.
- Sets up `profiles`, `scans`, `user_feedback`, `app_config`, and `data_deletion_requests` tables.
- Creates `herbarium-images` and `training-datasets` storage buckets with RLS policies.
- Seeds the initial required rows (e.g., Yerba Buena DOH reference).

---

## 2. Deploying Edge Functions

HerbaScan utilizes two Deno Edge Functions for administrative account management. These must be deployed manually.

```bash
npx supabase functions deploy delete-user
npx supabase functions deploy force-verify-user
```
*(Ensure your `supabase/config.toml` sets `verify_jwt = false` for these functions so they can handle asymmetric JWT verification internally).*

---

## 3. Account Roles & Deactivation

### Making an Account an Admin
To view the "Review Submissions" panel and access the Admin Dashboard, your account must have the `admin` role.

1. Find your user UUID in Supabase (Authentication → Users).
2. Run this command in the Supabase SQL Editor:
```sql
UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';
```

### Deactivating an Account
Admins can set `is_active = false` and provide a `suspension_reason` in the `public.profiles` table. The affected user will be immediately logged out and shown an `AccountSuspendedScreen` detailing the reason.

---

## 4. Auth & Email Configuration

### Recommended Auth Settings
For the best UX in an offline-first mobile app, we recommend adjusting the default Supabase email configurations (Authentication → Providers → Email):

1. **Disable "Confirm Email"**: Turn this OFF so users can sign in immediately without wrestling with deep-linked web redirects that fail on localhost.
2. **Enable Leaked Password Protection**: Turn this ON (if on a Pro plan) to reject passwords found in HaveIBeenPwned databases.
3. **App Deep Links**: Ensure your **Site URL** and **Redirect URLs** (Authentication → URL Configuration) include `herbascan://auth/callback` so password reset links open the app natively.

### 6-Digit OTP Bypass
HerbaScan's password reset and email confirmation templates support **6-digit OTP codes** to avoid link-scanning issues.
To utilize this, edit your Supabase Email Templates to include `{{ .Token }}` instead of just the link.

```html
<p>Enter this 6-digit code in the HerbaScan app:</p>
<p><strong>{{ .Token }}</strong></p>
```
