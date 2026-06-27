# HerbaScan – Quick Setup Guide

## Prerequisites

| Requirement | Version | Notes |
| --- | --- | --- |
| Flutter SDK | 3.9.2+ | |
| Dart SDK | bundled with Flutter | |
| Android Studio | Latest stable | Or VS Code with Flutter extensions |
| Android SDK | API 21+ | Required for Android deployment |

---

## 1. Install Flutter & Dependencies

Install Flutter for your OS ([Installation Guide](https://flutter.dev/docs/get-started/install)), ensuring `flutter doctor` passes without major issues.

```bash
# Clone the repository
git clone <repository-url>
cd RE-HerbaScan

# Install Flutter dependencies
flutter pub get

# Verify installation
flutter doctor
```

---

## 2. Run the App

The primary target is an Android device. Emulators do not support the camera or TFLite hardware acceleration well.

```bash
# Android device (recommended)
flutter run

# Windows desktop (admin portal testing — no camera/TFLite)
flutter run -d windows
```

### Build Commands

```bash
# Release APK (split per ABI — recommended for production)
flutter build apk --split-per-abi

# Universal APK
flutter build apk
```

---

## 3. Supabase Configuration (Cloud DB & Auth)

Supabase credentials are set in `lib/core/config/supabase_config.dart`. The project defaults to the production instance `tsahfzmxqsgbxrrtbdnw.supabase.co`.

**To provision a fresh database, apply all migrations via the CLI:**

```bash
# Link project (run once)
npx supabase login
npx supabase link --project-ref <YOUR_PROJECT_REF>

# Push all migrations to build the tables and RLS policies
npx supabase db push

# Deploy the Edge Functions
npx supabase functions deploy delete-user
npx supabase functions deploy force-verify-user
```

**Grant Admin Access:**
Run this in the Supabase SQL Editor to gain access to the HerbaScan Admin Portal:
```sql
UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';
```

> **Detailed Guide**: For comprehensive Supabase configuration (e.g. Email templates, Magic Links, Storage Buckets), refer to [`supabase/README.md`](supabase/README.md).

---

## 4. Local Database (SQLite)

HerbaScan is offline-first. The local SQLite database is created automatically on the first app launch. No manual setup is required. 

- **First Launch**: Automatically seeded with all medicinal plant structures.
- **Subsequent Launches**: Automatically syncs the latest catalog from Supabase via `CatalogSyncService` when online.

---

## 5. Backend API (Model Retraining)

**The backend is NOT required for plant scanning.** 
Plant identification runs fully offline via TFLite. The backend is an optional microservice used exclusively for retraining the ML model via a Modal GPU pipeline.

> **Detailed Guide**: If you need to deploy or modify the retraining pipeline, refer to [`backend/QUICK_START.md`](backend/QUICK_START.md) and [`backend/README.md`](backend/README.md).

---

## 6. Development Tips

```bash
# Hot reload (keeps state)
r

# Hot restart (resets state)
R

# Run widget tests
flutter test

# Analyze code for issues
flutter analyze
```
