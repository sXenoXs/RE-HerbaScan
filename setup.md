# HerbaScan – Quick Setup Guide

## Prerequisites

| Requirement | Version | Notes |
| --- | --- | --- |
| Flutter SDK | 3.9.2+ | |
| Dart SDK | bundled with Flutter | |
| Android SDK | API 21+ | For Android target |
| Android Studio | Latest stable | Or VS Code with extensions |
| Python | 3.8+ | Backend only — optional |

---

## 1. Install Flutter

### Windows

1. Download Flutter SDK from [flutter.dev/docs/get-started/install/windows](https://flutter.dev/docs/get-started/install/windows)
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your PATH environment variable
4. Run `flutter doctor` to verify installation

### macOS

1. Download from [flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
2. Extract to your home directory
3. Add Flutter to PATH in `~/.zshrc` or `~/.bash_profile`
4. Run `flutter doctor` to verify installation

### Linux

1. Download from [flutter.dev/docs/get-started/install/linux](https://flutter.dev/docs/get-started/install/linux)
2. Extract to your home directory
3. Add Flutter to PATH in `~/.bashrc`
4. Run `flutter doctor` to verify installation

---

## 2. Install Dependencies

```bash
# Navigate to project directory
cd RE-HerbaScan

# Install Flutter dependencies
flutter pub get

# Verify installation
flutter doctor
```

---

## 3. Run the App

```bash
# Android device (primary target — camera + TFLite work here)
flutter run

# Windows desktop (admin portal testing — no camera/TFLite)
flutter run -d windows

# Web
flutter run -d web

# iOS (macOS only)
flutter run -d ios
```

---

## 4. Build Commands

```bash
# Release APK (split per ABI — recommended)
flutter build apk --split-per-abi

# Universal APK
flutter build apk

# Analyze for issues
flutter analyze
```

---

## 5. IDE Setup

### Android Studio

1. Install Android Studio (latest stable)
2. Install Android SDK — API level 21 or higher
3. Enable USB Debugging on your physical device (recommended; camera not available in emulator)
4. Install Flutter and Dart plugins

### VS Code

1. Install the Flutter and Dart extensions
2. Open the project folder
3. Use `Ctrl+Shift+P` → "Flutter: Select Device" to target a device

---

## 6. Asset Files (already bundled — no action needed)

The following files are bundled in the repo and require no separate download for normal development:

| File | Location | Purpose |
| --- | --- | --- |
| `mobilenetv2_multi_output.tflite` | `assets/models/` | 31-class offline TFLite inference model |
| `class_indices.json` | `assets/models/` | Label map — name→index (31 entries) |
| `plant_explanations.json` | `assets/data/` | Deterministic XAI text for 30 plants |
| `safety_profiles.json` | `assets/data/` | Contraindication Engine data for 30 plants |
| `plant_habitats.json` | `assets/data/` | Habitat coordinates for habitat map |
| `doh_plants.json` | `assets/data/` | DOH-approved plant metadata (10 plants) |
| `default_plant_anatomy.json` | `assets/data/` | 2D silhouette anatomy parts for 30 plants |
| `ood_safety_config.json` | `assets/data/` | OOD thresholds — `num_classes=31`, `not_plant_index=19`, `confidence_threshold=0.85` |

> **Note (v1.0.7):** `mobilenetv2_cam_weights.json` was permanently deleted when the GradCAM/CAM heatmap system was removed. It is not present and not required. The app uses a classification-only inference pipeline.

---

## 7. Supabase Configuration

Supabase credentials are set in `lib/core/config/supabase_config.dart`. The project is already configured for `tsahfzmxqsgbxrrtbdnw.supabase.co`.

**Apply all 23 migrations via CLI (recommended):**

```bash
# Link project (run once)
npx supabase login
npx supabase link --project-ref tsahfzmxqsgbxrrtbdnw

# Push all pending migrations
npx supabase db push
```

**Deploy Edge Functions:**

```bash
npx supabase functions deploy delete-user
npx supabase functions deploy force-verify-user
```

**Grant admin role to your account:**

```sql
UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';
```

> For full Supabase setup steps (storage bucket, URL configuration, email OTP templates), see `supabase/README.md`.

---

## 8. Local Database (SQLite)

The SQLite database is created automatically on first app launch. No manual setup is required.

**9 tables auto-created and seeded:**

| Table | Purpose |
| --- | --- |
| `plants` | 30 medicinal plants (29 ML-mapped + Yerba Buena browse-only); optional `image_url` |
| `medicinal_uses` | Therapeutic applications per plant |
| `preparation_methods` | Preparation steps with step details and schedule JSON |
| `scan_history` | Local scan results with predictions and metadata |
| `catalog_conditions` | Condition list (synced from Supabase when online) |
| `catalog_condition_plants` | Condition–plant mapping |
| `safety_profiles` | Contraindication data; includes `needs_strict_contraindications` |
| `plant_habitats` | Coordinates, region names, climate notes |
| `catalog_plant_anatomy` | SVG path data for 2D interactive silhouette |

Seeded from `PlantDataService.getAllMedicinalPlantsData()` on first launch (30 plants). When online, `CatalogSyncService` overwrites catalog tables from Supabase on every app open.

---

## 9. Backend Setup (Optional — Model Retraining Only)

> The Railway backend is **not called during plant scanning**. All identification runs fully offline via TFLite on-device. The backend handles model retraining (via Modal GPU pipeline) and hot-reload only.

**Production URL:** `https://re-herbascan-production.up.railway.app`

### Local Backend Setup

```bash
cd backend

# Windows
python -m venv venv
venv\Scripts\activate

# Mac/Linux
python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt
```

**Required model file** — place in `backend/models/`:

```text
backend/models/
└── MobileNetV2_model.keras    ← required for retraining
```

> `labels.json` in `backend/models/` is optional. The backend generates 31 placeholder labels if it is absent.

```bash
# Run locally
python main.py
# Or
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Verify
curl http://localhost:8000/health
```

### Regenerating TFLite Assets After Retraining

If the Keras model is retrained, regenerate the Flutter TFLite asset:

```bash
cd backend

# Create multi-output TFLite model (classification outputs: [1,7,7,1280] features + [1,31] predictions)
python create_multi_output_tflite.py
# → backend/models/mobilenetv2_multi_output.tflite

# Copy to Flutter assets
cp models/mobilenetv2_multi_output.tflite ../assets/models/

# Update class_indices.json if class mappings changed
# assets/models/class_indices.json — format: {"PlantName": index}

# Rebuild Flutter app
flutter clean && flutter pub get && flutter run
```

> `extract_cam_weights.py` is no longer used — GradCAM/CAM weights were removed in v1.0.7.

### Backend Environment Variables (Railway)

| Variable | Required | Notes |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | Yes | Shared secret for `/admin/reload-model` and `/admin/trigger-training` |
| `MODAL_TRAINING_URL` | Yes | Modal web endpoint for training trigger |
| `SUPABASE_JWT_SECRET` | **Not recommended** | Leave unset — prevents 401 for anonymous users on `/identify` |

> For full Railway deployment steps, see `backend/README.md` and `backend/QUICK_START.md`.

---

## 10. Key Configuration Files

| File | Purpose |
| --- | --- |
| `lib/core/config/supabase_config.dart` | Supabase URL and anon key |
| `lib/core/theme/app_theme.dart` | Design tokens — Botanical Emerald `#16A34A`, Material 3, Inter font |
| `assets/data/ood_safety_config.json` | OOD thresholds (`num_classes=31`, `not_plant_index=19`, `confidence_threshold=0.85`) |
| `assets/models/class_indices.json` | 31-class label map — keep in sync with backend `labels.json` after retraining |
| `lib/features/admin/widgets/trigger_training_widget.dart` | Contains the Railway backend URL for training trigger |
| `pubspec.yaml` | All Flutter/Dart dependencies |

---

## 11. Troubleshooting

### Flutter not found

- Verify Flutter is added to PATH; restart your terminal
- Run `flutter doctor` to identify configuration gaps

### Android SDK not found

- Install Android Studio; accept licenses with `flutter doctor --android-licenses`

### Device not detected

- Enable USB Debugging on Android device
- Run `flutter devices` to list available targets
- Camera and TFLite inference require a real device (not emulator)

### Dependencies not installing

- Check internet connection
- Run `flutter clean` then `flutter pub get`
- Check `pubspec.yaml` for syntax errors

### TFLite model not loading

- Verify `assets/models/mobilenetv2_multi_output.tflite` exists
- Verify `pubspec.yaml` declares `assets/models/` as an asset path
- Run `flutter clean && flutter pub get && flutter run`

### Offline explanations not showing

- Verify `assets/data/plant_explanations.json` exists and is valid JSON
- Verify `pubspec.yaml` includes `assets/data/` in the assets list

### SQLite errors (desktop)

- Desktop (Windows/Linux/macOS) uses `sqflite_common_ffi` — confirm it is in `pubspec.yaml`
- `sqflite` is for mobile; `sqflite_common_ffi` is required for desktop

### Supabase 403 when saving to cloud

- Storage RLS policies may be missing — run migration `20260302000000_storage_herbarium_policies.sql` or `npx supabase db push`
- Confirm the `herbarium-images` bucket exists in your Supabase project

### Railway 401 when triggering training

- Verify `ADMIN_RELOAD_SECRET` on Railway matches the value in `trigger_training_widget.dart`
- Do **not** set `SUPABASE_JWT_SECRET` on Railway — leave it unset

### Backend cold start delay

- First Railway request takes 10–30 s (TensorFlow model load); warm requests take 2–4 s
- This only affects model retraining triggers — plant scanning is fully offline and unaffected

---

## 12. Development Tips

```bash
# Hot reload (keeps state)
r

# Hot restart (resets state)
R

# Debug mode
flutter run --debug

# Release mode (performance testing)
flutter run --release

# List available devices
flutter devices

# Analyze code
flutter analyze

# Run widget tests
flutter test
```

### Performance tips

- Use `flutter build apk --split-per-abi` for smaller release APKs
- Monitor memory with Flutter Inspector during development
- Test on a real Android device — emulators do not support camera or TFLite

---

## 13. Project Structure Reference

```text
RE-HerbaScan/
├── lib/
│   ├── core/
│   │   ├── config/        ← Supabase URL + anon key
│   │   ├── models/        ← Data models (Plant, ScanResult, CloudScan, …)
│   │   ├── providers/     ← 6 providers: App, Auth, Plant, Camera, Language, Offline
│   │   ├── services/      ← 30+ services (TFLite, XAI, Auth, Herbarium, CatalogSync, …)
│   │   ├── theme/         ← app_theme.dart (Botanical Emerald, Material 3)
│   │   ├── widgets/       ← Shared widgets
│   │   ├── routing/       ← app_router.dart (GoRouter)
│   │   └── localization/  ← English / Filipino
│   ├── features/          ← Screen modules (scan, browse, history, admin, auth, …)
│   └── main.dart
├── assets/
│   ├── models/            ← mobilenetv2_multi_output.tflite, class_indices.json
│   ├── data/              ← plant_explanations.json, safety_profiles.json, …
│   ├── images/            ← 50+ plant reference JPEGs
│   └── icons/             ← HerbaScan_Icon1.svg, HerbaScan_Icon1.png
├── backend/               ← Python FastAPI — model retraining pipeline only
│   ├── main.py
│   ├── modal_train.py     ← Modal T4 GPU training pipeline
│   └── models/            ← MobileNetV2_model.keras (place here for retraining)
├── supabase/
│   ├── migrations/        ← 19 SQL migrations
│   └── functions/         ← delete-user, force-verify-user (Deno Edge Functions)
├── android/
├── ios/
└── pubspec.yaml
```
