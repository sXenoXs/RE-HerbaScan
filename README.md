# HerbaScan - AI-Powered Plant Identification App

**Thesis Project**: HERBASCAN: A CONVOLUTIONAL NEURAL NETWORK-BASED MOBILE APPLICATION FOR PLANT IDENTIFICATION AND HERBAL MEDICINE INFORMATION

HerbaScan is a Flutter-based mobile application that uses a MobileNetV2 Convolutional Neural Network to identify Philippine medicinal plants fully offline. The app provides comprehensive information about DOH-approved herbal medicines and supports offline processing for rural areas.

**Academic Context**: Undergraduate Thesis — College of Information Technology and Computer Science, Lyceum of the Philippines University-Cavite
**Client/Partner**: Philippine Institute of Traditional and Alternative Health Care (PITAHC)
**Dataset**: PhilMedic — 4,922 leaf images, medicinal plant classes native to the Philippines

---

## Current Development Status

**Version**: v1.0.22
**Last Updated**: May 25, 2026
**Overall Progress**: ~98% Complete — **PRODUCTION READY**

---

## Core Features

### Plant Identification (Offline-First)

- **MobileNetV2 TFLite** — 31-class model (29 plant classes + `Not_Plant`@19 + `UnknownPlant`@30), fully offline on-device
- **Two-Stage Quality Gate** — Stage 1: brightness / blur / edge density; Stage 2: OOD confidence gate (0.85 threshold from `ood_safety_config.json`)
- **Normalization**: `[-1, 1]` range per MobileNetV2 training convention
- **Labels**: `assets/models/class_indices.json` (name→index format); no `labels.txt`
- **Top-3 Predictions** with confidence percentages; OOD results show "Not identified" badge (no misleading confidence %)
- **Toxic Plant Blacklist** (app-layer): Adelfa, IpilIpil, TubaTuba — dedicated warning screen, never auto-saved, never shown as a recommended result; handled by name match, not model index
- **No GradCAM/CAM heatmap system** — removed in v1.0.7 for a classification-only pipeline

### Plant Knowledge & Information

- **30-plant catalog** (29 ML output classes + Yerba Buena as browse-only DOH plant); 10 DOH-approved + additional medicinal plants
- **Plant Detail Screen** — 4 tabs: Taxonomy, Ecology, Medicinal, Safety
- **Interactive 2D Plant Silhouette** — SVG path hit-testing, DB-backed anatomy data
- **Preparation Guide** (renamed from Instructions) — interactive checklist, contextual timers, Focus Mode, calendar add-to-device; step-type icon cards (boil → orange, herb → green, strain → teal, cool → blue, drink → amber) with 44 px animated circles
- **Contraindication Engine** — deterministic safety assessment from `safety_profiles.json`; `needs_strict_contraindications` flag shows prominent "Use with strict caution" card (e.g. Kamias, Kamoteng Kahoy, Kakawate)
- **XAI Explanation System** — fully offline, no live LLM; resolution chain: SharedPreferences cache → `plant_explanations.json` (29 classes, 4-section format) → fallback text
- **Static Habitat Heatmap** — `flutter_map` + curated coordinates
- **Condition-based Search** — 15+ medical conditions, DB-backed and admin-manageable
- **Browse & Search** — SearchBar, SegmentedButton (All Plants / DOH Approved / By Condition), grid/list view, compact Medical Conditions ActionChip pill in toolbar

### Scan History & Cloud Sync

- **Device Tab** — SQLite `scan_history`; swipe export/delete; select mode with batch upload
- **Cloud Tab** — Supabase `scans` table; pull-to-refresh; select mode with batch download; tap cloud card to open full Plant Result screen with correct cloud image rendering
- **Auto-save toggle** — `auto_save_scans` preference (SharedPreferences); when OFF, new scans are not auto-saved until user saves from Plant Result or History
- **Share** — "Share as Info Card" (rich PNG card: scan image, plant name, confidence, DOH status, medicinal uses, HerbaScan branding) and "Share as Text" via native OS share sheet

### Auth & Account

- Email + password sign-up with 6-digit OTP confirmation
- 6-digit OTP password reset (bulletproof — avoids link-scanner issue)
- Change password (with live requirements widget), change email
- Delete account via `delete-user` Edge Function
- RBAC: `user` / `admin` roles via `profiles.role` + `is_admin()` SECURITY DEFINER
- Sign-out confirmation dialog before signing out
- Friendly auth error messages for all failure states

### Admin Portal (all platforms — Android, Windows, Web)

- **Admin routing**: Admins go directly to `/admin` from splash; `/home` redirects to `/admin` for admin users
- **Image Review** — Approve (Approve only / Approve + Add to Training Data), Reject, Delete; "Training eligible" badge on approved scans; `_CopyingProgressDialog` during storage copy
- **Plant Metadata Editor** — 6-tab form (Identity, Ecology, Medicinal, Preparations, Safety, Anatomy); cloud-first; instant local sync after save
- **Training Images Sheet** — manual upload + approved scan count with "Include in next training run" toggle; `TriggerTrainingWidget` for one-tap Modal GPU training
- **Condition Search Management** — add / edit / delete conditions + plant mapping
- **User Management** — make admin / remove admin, force activate email (OTP bypass), deactivate, delete
- **System Health** — enhanced error logs with filter chips (All / Camera / AI / Database / Network), expandable list, individual `ExpansionTile` entries with full message + stack trace; Export modal bottom sheet (JSON / MD / CSV / Text) with clipboard copy and file download via `share_plus`
- **Feedback** — view and delete user feedback entries
- **Factory Reset** — re-seeds catalog to Supabase
- **Supabase Realtime sync** — `PlantProvider` subscribes to 8 catalog tables; admin edits appear in-app instantly via `syncSinglePlant` / `syncConditionsOnly`
- **Theme-aware UI** — all admin screens (Overview, New Plant Wizard, sidebar rail/drawer, Toxic Plants cards, System Health export) adapt to light and dark mode

### Settings & Offline

- **System Diagnostics** (renamed from Offline Demo) — 2×2 stat cards, connection banner, Force Sync / Wipe Cache
- **Offline storage info + refresh** — wipes device scan history on demand
- **Persistent user preferences** — SharedPreferences; show_confidence, show_top3, auto_save_scans
- **English / Filipino localization** — runtime switching
- **Medical Disclaimer screen** — one-time first-launch overlay (acknowledged state persisted to SharedPreferences); routes to `/disclaimer` with destination as `extra`

### UI / UX

- **App icon & splash** — HerbaScan_Icon1 SVG splash icon; all five Android mipmap densities updated; native splash background `#F4F7F4` (Soft Sage) eliminates white flash
- **Material Design 3** with Botanical Emerald theme (`#16A34A`), Inter font, dark Forest Black/slate-green surfaces
- **BottomAppBar** + center camera FAB; FAB hides when keyboard is open
- **Browse keyboard fix** — `resizeToAvoidBottomInset: false`; tap outside to dismiss search
- **SnackBar** — floating behavior so camera FAB is not displaced
- **Page transitions** — slide, fade, scale routes throughout

---

## Recent Changes

### v1.0.22 — May 25, 2026

- **Yerba Buena re-added as browse-only DOH plant** — no model class (`class_indices.json` unchanged). Migration `20260525000000_readd_yerba_buena_browse_only.sql` applied. `_getYerbaBuenaData()` added to `plant_data_service.dart` as the 10th DOH-approved plant. Entries added to `plant_explanations.json`, `safety_profiles.json`, `plant_habitats.json`, `default_plant_anatomy.json`, `doh_plants.json`. Supabase catalog now has 30 rows.

### v1.0.21 — May 24, 2026

- **Toxic plant cards** — removed noisy symptoms / toxin text from browse grid and list cards (`_buildToxicGridCard`, `_buildToxicListCard`); overflow eliminated; harm badge retained.

### v1.0.20 — May 24, 2026

- **Export bottom sheet** — SegmentedButton JSON/MD/CSV/Text labels: fontSize 12→11, `expandedInsets` symmetric horizontal padding, `maxLines:1`/`overflow:ellipsis` to prevent label wrapping.

### v1.0.19 — May 24, 2026

- **Cloud scan image blank** — `_cloudScanToScanResult()` now injects `imageUrl` into `mergedMetadata`; `_buildHeroBackground()` detects HTTP URL and uses `Image.network` for cloud history, `Image.file` for local captures.

### v1.0.18 — May 24, 2026

- **Browse toxic grid card overflow** — `childAspectRatio` 0.82 → 0.72; inner `Column` wrapped in `ClipRect`; `withOpacity` → `withValues(alpha:)` deprecation fixed.

### v1.0.17 — May 24, 2026

- **Admin System Health export section** — `Card` → `Container` with border; `SegmentedButton` in export sheet: `showSelectedIcon:false`, adaptive `backgroundColor`/`foregroundColor`, 12sp text.

### v1.0.16 — May 24, 2026

- **Admin New Plant Wizard** — AppBar and `_StepIndicator` fully theme-aware (adaptive backgrounds, borders, circle fills, label colors for dark/light).

### v1.0.15 — May 24, 2026

- **Splash icon** — background circle removed (green disc was visible on both modes); Container replaced with SizedBox. Fixed `withOpacity` deprecation on `LinearProgressIndicator`.
- **Admin Overview SliverAppBar** — seamless `scaffoldBackgroundColor`; adaptive title and icon colors; `scrolledUnderElevation: 1`.

### v1.0.14 — May 24, 2026

- **Browse Medical Conditions Banner** — full-width SliverToBoxAdapter removed; replaced with compact `ActionChip` pill in toolbar row between count text and grid/list toggle; only shown when `!isToxic`.

### v1.0.13 — May 24, 2026

- **Admin sidebar, rail, drawer** — fully theme-adaptive colors for light mode (surface, onSurface). Admin Toxic Plants card refactored to column layout — buttons on bottom row, prevents long name overflow on 360dp screens. Browse `SegmentedButton` label wrapping fixed (`showSelectedIcon: false` + 12sp).

### v1.0.12 — May 24, 2026

- **Approved-image-to-training pipeline** — SQL migration `20260524000001_scan_training_eligible.sql` (`training_eligible`, `training_copied_at` columns on `scans` table, partial index, storage policies). `HerbariumService`: `approveForTraining`, `getTrainingEligibleScans`, `getTrainingEligibleScanCount`. Admin Submission Triage: `_ApproveActionSheet` (Approve only / Approve + Add to Training Data), `_CopyingProgressDialog`, "Training eligible" badge. Training Images sheet shows approved scan count + include toggle. Admin Overview metrics sum manual uploads + approved scans.

### v1.0.11 — May 24, 2026

- **Admin System Health** — error logs: filter chip row (All / Camera / AI / Database / Network), expandable list (default 5, "Show all N" toggle), individual `ExpansionTile` entries (message, stack trace, context), error type color coding. Export section: modal bottom sheet (JSON / MD / CSV / Text), clipboard copy, file download via `share_plus`.

### v1.0.10 — May 24, 2026

- **OOD confidence display** — when top prediction is `Not_Plant` or `UnknownPlant`, confidence scores are hidden everywhere (badge shows "Not identified" in red; alternative match confidence % suppressed). `_isOODResult` getter + `_toDisplayName()` for human-readable labels.

### v1.0.9 — May 24, 2026

- **Security** — RLS enabled on `public.model_versions`; 4 policies: SELECT open to all, INSERT/UPDATE/DELETE restricted to admins via `is_admin()`.

### v1.0.8 — May 24, 2026

- **Supabase catalog alignment** — migration `20260523000000_reduce_catalog_to_31_classes.sql` deleted 13 plant rows (child-first order) not in the 31-class model. `ai_vision_summary` column drop guard added. `user_feedback` migration idempotency fixed.

### v1.0.7 — May 23, 2026

- **GradCAM system fully removed** — `adaptive_gradcam_service.dart`, `online_gradcam_service.dart`, `offline_cam_service.dart`, `gradcam_visualization.dart` and all related test files deleted. `PlantResultScreen` simplified to classification-only (no heatmap tab). `AppProvider` `showGradCAM` preference removed. `aiVisionSummary` field removed from admin and metadata service.
- **42 → 31 plant alignment** — 13 plants not in the TFLite model removed from `plant_explanations.json`, `safety_profiles.json`, `plant_habitats.json`, `default_plant_anatomy.json`, and `plant_data_service.dart`. Backend `range(42)` → `range(31)`.
- **System Diagnostics** — renamed from Offline Demo (`OfflineDemoScreen` → `SystemDiagnosticsScreen`).

### v1.0.6 — May 22, 2026

- **FAB keyboard overlap** — camera FAB hidden when keyboard is open. Browse `resizeToAvoidBottomInset: false`. "Scanning & Recognition" section renamed in Settings. GradCAM toggle removed from Settings.

### v1.0.5 — May 22, 2026

- **Medical Disclaimer screen** (`/disclaimer` route) — one-time first-launch overlay; acknowledged state in SharedPreferences.
- **Sign-out confirmation dialog** — requires explicit confirmation before signing out.
- **Rich share card** — "Share as Info Card" renders a 380 px PNG card off-screen via `RenderRepaintBoundary`; "Share as Text" sends a structured plain-text payload.

### v1.0.4 — May 22, 2026

- **History kebab menu** — Sort and Select merged into single `PopupMenuButton`. Batch FAB labels renamed: "Upload Selected Images" / "Download Selected Images". Cloud card tap navigates to full Plant Result screen.

### v1.0.3 — May 22, 2026

- **App launcher icon** — all five Android mipmap densities updated to `HerbaScan_Icon1.png`.
- **Splash screen icon** — `Icons.eco_rounded` replaced with `SvgPicture.asset('assets/icons/HerbaScan_Icon1.svg')`. `flutter_svg` dependency added.
- **Native splash background** — `#F4F7F4` (Soft Sage) eliminates the white flash before Flutter renders.


---

## Technical Architecture

- **Framework**: Flutter 3.9.2+
- **State Management**: Provider pattern — 6 providers: App, Auth, Plant, Camera, Language, Offline
- **Local Database**: SQLite (`sqflite` on mobile, `sqflite_common_ffi` on desktop) — 9 tables, offline-first
- **Cloud Database**: Supabase PostgreSQL — catalog master, scans, profiles, user_feedback
- **AI/ML**: TensorFlow Lite (`tflite_flutter ^0.11.0`) — MobileNetV2 31-class, fully offline on-device
- **Inference**: Classification-only pipeline (no heatmap); two-stage quality gate
- **XAI Explanations**: Fully deterministic — `plant_explanations.json`, no live LLM
- **Auth**: Supabase Auth — email + 6-digit OTP; RBAC via `is_admin()` SECURITY DEFINER
- **Backend**: Python FastAPI on Railway — model retraining pipeline only (not used during scanning)
- **Routing**: GoRouter (`go_router ^14.6.2`)
- **Connectivity**: `connectivity_plus ^7.0.0`
- **Localization**: Flutter i18n — English / Filipino

### Routing Table

| Route | Screen | Guard |
| --- | --- | --- |
| `/` | `SplashScreen` | None |
| `/disclaimer` | `DisclaimerScreen` | None |
| `/login` | `LoginScreen` | None |
| `/home` | `HomeScreen` | Redirects to `/admin` if admin |
| `/onboarding` | `OnboardingScreen` | None |
| `/admin` | `AdminWebScreen` | Login + admin role |

### File Structure

```
RE-HerbaScan/
├── lib/
│   ├── core/
│   │   ├── config/        (Supabase URL / anon key, auth redirect)
│   │   ├── constants/     (condition_icons, toxic_plant_blacklist)
│   │   ├── models/        (Plant, ScanResult, CloudScan, UserFeedback, SafetyProfile, …)
│   │   ├── providers/     (App, Auth, Plant, Camera, Language, Offline)
│   │   ├── services/      (Database, Plant, TFLite, XAI, Auth, Herbarium, CatalogSync,
│   │   │                   OtaModel, TrainingDataset, CatalogPlantAdmin, Safety, Habitat,
│   │   │                   Condition, Feedback, Performance, Analytics, ErrorLogger, …)
│   │   ├── widgets/       (offline_indicator, auth_deeplink_handler,
│   │   │                   botanical_auth_header, contraindication_engine_widget,
│   │   │                   anatomy_interactive_view, plant_image, …)
│   │   ├── routing/       (app_router.dart — GoRouter)
│   │   ├── theme/         (app_theme.dart — Emerald botanical green, Material 3)
│   │   ├── localization/  (app_localizations.dart)
│   │   └── utils/         (page_transitions, preparation_step_parser, svg_path_parser, …)
│   ├── features/
│   │   ├── admin/         (dashboard, overview, plant catalog editor, toxic plants,
│   │   │                   user management, system health, feedback, new plant wizard,
│   │   │                   widgets/trigger_training_widget)
│   │   ├── auth/          (login, signup, forgot password, OTP, change email/password)
│   │   ├── browse/        (browse, condition search, condition results, toxic detail)
│   │   ├── doh/           (doh_screen)
│   │   ├── feedback/      (bottom sheet, form, screen)
│   │   ├── help/          (help_tutorial_screen)
│   │   ├── history/       (history_screen — Device + Cloud tabs)
│   │   ├── home/          (home_screen)
│   │   ├── offline/       (system_diagnostics_screen)
│   │   ├── onboarding/    (onboarding_screen)
│   │   ├── scan/          (scan, plant result, plant detail, habitat map,
│   │   │                   preparation guide, focus mode, no match, poor quality)
│   │   ├── settings/      (settings_screen)
│   │   └── splash/        (splash_screen, disclaimer_screen)
│   └── main.dart
├── assets/
│   ├── models/
│   │   ├── mobilenetv2_multi_output.tflite   (31-class offline inference)
│   │   └── class_indices.json                (name→index label map)
│   ├── data/
│   │   ├── plant_explanations.json           (4-section XAI for 29 plant classes + Yerba Buena)
│   │   ├── safety_profiles.json              (Contraindication Engine data)
│   │   ├── plant_habitats.json               (habitat coordinates)
│   │   ├── doh_plants.json                   (DOH-approved plant metadata)
│   │   ├── default_plant_anatomy.json        (2D anatomy parts)
│   │   └── ood_safety_config.json            (OOD thresholds — num_classes=31, not_plant_index=19)
│   ├── images/                               (50+ plant reference JPEGs)
│   ├── icons/                                (HerbaScan_Icon1.svg, HerbaScan_Icon1.png)
│   └── fonts/                                (Inter variable font)
├── backend/                                  (Python FastAPI — retraining pipeline only)
│   ├── main.py
│   ├── modal_train.py                        (Modal T4 GPU training pipeline)
│   ├── models/
│   │   ├── MobileNetV2_model.keras           (source model for retraining)
│   │   ├── labels.json
│   │   └── ood_safety_config.json
│   └── utils/  (preprocessing, validation_pipeline, gradcam — server-side only)
└── supabase/
    ├── migrations/  (19 SQL migrations)
    └── functions/   (delete-user, force-verify-user — Deno Edge Functions)
```

---

## AI Model Integration

### Current Status

- ✓ MobileNetV2 TFLite — 31 classes (29 plants + `Not_Plant`@19 + `UnknownPlant`@30)
- ✓ Fully offline on-device inference via `assets/models/mobilenetv2_multi_output.tflite`
- ✓ Two-stage image quality gate (brightness, blur, edge density) before inference
- ✓ OOD confidence threshold: 0.85 (from `ood_safety_config.json`)
- ✓ Normalization: `(pixel / 255.0) * 2.0 - 1.0` → `[-1, 1]`
- ✓ Performance Metrics: Accuracy 89.23%, Precision 87.56%, Recall 88.34%, F1-Score 87.95%
- ✓ Backend API — Python FastAPI on Railway for model retraining pipeline only
- ✓ Modal T4 GPU automated training pipeline triggered from admin panel

### Backend API (Python FastAPI — Model Retraining Only)

Plant identification runs **fully offline on-device** via TFLite. The Railway backend is used exclusively for model retraining and model reload.

**Location**: `backend/` — **URL**: `https://re-herbascan-production.up.railway.app`

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Server health + model load status |
| `GET /test` | Debug / connectivity check |
| `POST /identify` | Plant ID + server-side Grad-CAM (not called by Flutter during normal scanning) |
| `POST /admin/trigger-training` | Validates admin secret, forwards to Modal GPU pipeline |
| `POST /admin/reload-model` | Hot-swaps `MobileNetV2_model.keras` from Supabase storage |

**Required environment variables**:

| Variable | Required | Notes |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | Yes | Shared secret for admin endpoints |
| `MODAL_TRAINING_URL` | Yes | Modal web endpoint for training trigger |
| `SUPABASE_JWT_SECRET` | Not recommended | Leave unset — prevents 401 for anonymous users on `/identify` |

### Phase 2: Multi-Output TFLite Extraction

When the Keras model is retrained, regenerate Flutter offline assets:

```bash
cd backend

# Option A: update scripts to reference .keras directly
# Edit extract_cam_weights.py and create_multi_output_tflite.py:
#   MODEL_PATH = Path("models/MobileNetV2_model.keras")

# Extract weights matrix [1280, 31]
python extract_cam_weights.py
# → models/mobilenetv2_cam_weights.json

# Create multi-output TFLite (outputs: [1,7,7,1280] features + [1,31] predictions)
python create_multi_output_tflite.py
# → models/mobilenetv2_multi_output.tflite

# Copy to Flutter assets
cp models/mobilenetv2_multi_output.tflite ../assets/models/
# Update assets/models/class_indices.json if class mappings changed
```

See `backend/README.md` → "Phase 2: Model Extraction & Conversion" for full details.

---

## Supabase Configuration

**Project**: `tsahfzmxqsgbxrrtbdnw.supabase.co`

### Migrations (applied in order)

| File | Purpose |
| --- | --- |
| `20260223000000_herbarium_schema.sql` | `profiles` + `scans` tables |
| `20260228000000_profiles_admin_and_email.sql` | `is_active`, `email` on profiles |
| `20260228000001_plant_metadata.sql` | `plant_metadata` table |
| `20260301000000_fix_profiles_rls_recursion.sql` | `is_admin()` SECURITY DEFINER |
| `20260302000000_storage_herbarium_policies.sql` | Storage RLS |
| `20260302100000_catalog_plants_schema.sql` | Full plant catalog schema |
| `20260302100001_storage_plant_catalog.sql` | Plant catalog storage bucket |
| `20260302200000_catalog_plant_anatomy.sql` | `catalog_plant_anatomy` table |
| `20260314000000_catalog_safety_strict_contraindications.sql` | `needs_strict_contraindications` column |
| `20260316000000_user_feedback.sql` | `user_feedback` table + RLS |
| `20260316000001_user_feedback_admin_delete.sql` | Admin delete policy on `user_feedback` |
| `20260425000000_toxic_plant_images.sql` | Toxic plant image storage |
| `20260502000000_admin_toxic_storage.sql` | Admin toxic image policies |
| `20260523000000_reduce_catalog_to_31_classes.sql` | Catalog aligned to 31-class model (42 → 29 rows) |
| `20260524000000_model_versions_rls.sql` | RLS on `model_versions` (SELECT open; CUD admins only) |
| `20260524000001_scan_training_eligible.sql` | `training_eligible` + `training_copied_at` on `scans`; training storage policies |
| `20260525000000_readd_yerba_buena_browse_only.sql` | Yerba Buena re-inserted across all 8 catalog tables as browse-only |

### Edge Functions

```bash
npx supabase functions deploy delete-user
npx supabase functions deploy force-verify-user
```

### Make your account admin

```sql
UPDATE public.profiles SET role = 'admin' WHERE id = 'YOUR_USER_UUID';
```

---

## Database Schema (SQLite Local)

| Table | Purpose |
| --- | --- |
| `plants` | 30 medicinal plants (29 model-aligned + Yerba Buena browse-only); optional `image_url` from Supabase |
| `medicinal_uses` | Therapeutic applications per plant |
| `preparation_methods` | Preparation steps, `step_details_json`, `schedule_json` |
| `scan_history` | Local scan results with predictions, metadata |
| `catalog_conditions` | Condition list (synced from Supabase) |
| `catalog_condition_plants` | Condition–plant mapping |
| `safety_profiles` | Contraindication data (synced from `catalog_safety`); includes `needs_strict_contraindications` |
| `plant_habitats` | Coordinates, region names, climate notes |
| `catalog_plant_anatomy` | SVG path data for 2D interactive silhouette |

Seeded from `PlantDataService.getAllMedicinalPlantsData()` on first launch. All catalog tables created on every open via `CREATE TABLE IF NOT EXISTS` for fresh-install safety.

---

## DOH-Approved Plants (10 Official)

| # | Common Name | Scientific Name | Primary Use |
| --- | --- | --- | --- |
| 1 | Akapulko | *Senna alata* | Fungal infections |
| 2 | Ampalaya | *Momordica charantia* | Asthma and coughs |
| 3 | Bawang | *Allium sativum* | Wounds and toothaches |
| 4 | Bayabas | *Psidium guajava* | Wounds and diarrhea |
| 5 | Lagundi | *Vitex negundo* | Cough and asthma |
| 6 | Niyog-niyogan | *Combretum indicum* | Expelling parasitic worms |
| 7 | Sambong | *Blumea balsamifera* | Lowering uric acid, hypertension |
| 8 | Tsaang Gubat | *Ehretia microphylla* | Stomachaches and diarrhea |
| 9 | Ulasimang-bato | *Peperomia pellucida* | Gout and rheumatism |
| 10 | Yerba Buena | *Clinopodium douglasii* | Muscle/joint pain, headaches (**browse-only** — no TFLite class yet) |

### Additional ML Model Classes (19)

AloeVera, Banaba, Calamansi, Gumamela, Guyabano, IndianMango, Kakwate, Kamias, Kamote, KamotengKahoy, Luya, Malunggay, Mayana, Oregano, PansitPansitan (= UlasimangBato / Peperomia pellucida), Pomelo, Saluyot, SampaSampalukan, Sampalok, SilingLabuyo, TawaTawa

### Toxic Plant Blacklist (app-layer; NOT model output classes)

Adelfa (*Nerium oleander*), Ipil-Ipil (*Leucaena leucocephala*), Tuba-Tuba (*Jatropha curcas*)

---

## Setup Instructions

### Prerequisites

1. **Flutter SDK** 3.9.2 or later — [flutter.dev](https://flutter.dev/docs/get-started/install)
2. **Android Studio** — Android SDK API 21+; USB debugging for physical device
3. **VS Code** (recommended) — Flutter + Dart extensions

No API key is required for XAI explanations — they come from `plant_explanations.json` and fallback only (no live LLM).

### Installation

```bash
git clone <repository-url>
cd RE-HerbaScan
flutter pub get
flutter run
```

### Build Commands

```bash
# Android debug
flutter run

# Windows desktop (admin portal testing — no camera/TFLite)
flutter run -d windows

# Release APK
flutter build apk --split-per-abi

# Analyze
flutter analyze
```

### Backend Setup (Optional — for model retraining)

```bash
cd backend
python -m venv venv
venv\Scripts\activate           # Windows
# source venv/bin/activate      # Mac/Linux

pip install -r requirements.txt

# Place MobileNetV2_model.keras in backend/models/
python main.py
curl http://localhost:8000/health
```

See `backend/README.md` and `backend/QUICK_START.md` for Railway deployment.

---

## Key Dependencies

| Package | Version | Purpose |
| --- | --- | --- |
| `provider` | ^6.1.2 | State management |
| `go_router` | ^14.6.2 | Declarative routing + admin guard |
| `supabase_flutter` | — | Auth, DB, Storage, Edge Functions |
| `sqflite` | ^2.4.0 | Local SQLite (mobile) |
| `sqflite_common_ffi` | ^2.3.7 | Local SQLite (desktop) |
| `tflite_flutter` | ^0.11.0 | On-device ML inference |
| `camera` | ^0.11.2+1 | Camera capture |
| `image_picker` | ^1.1.2 | Gallery selection |
| `image` | ^4.5.4 | Image preprocessing |
| `flutter_map` | ^7.0.2 | OpenStreetMap habitat visualization |
| `path_drawing` | ^1.0.1 | SVG path parsing for 2D silhouette |
| `connectivity_plus` | ^7.0.0 | Network status monitoring |
| `flutter_markdown` | ^0.6.18 | XAI explanation rendering |
| `cached_network_image` | ^3.4.1 | Supabase Storage plant images |
| `flutter_svg` | ^2.0.10+1 | SVG splash icon |
| `share_plus` | ^10.0.0 | Native OS share (text + file) |
| `gal` | ^2.3.0 | Export to gallery / camera roll |
| `add_2_calendar` | ^2.2.5 | Calendar add-event for prep schedule |
| `flutter_local_notifications` | ^18.0.0 | Preparation timer notifications |
| `pinput` | ^5.0.0 | 6-box OTP input |
| `http` | ^1.2.2 | Railway API calls |
| `path_provider` | ^2.1.5 | File paths for export |
| `shared_preferences` | ^2.3.2 | Persistent user preferences |

---

## Progress Metrics

| Metric | Value |
| --- | --- |
| **Version** | v1.0.22 |
| **Dart source files** | 114 |
| **Lines of code** | 12,000+ |
| **Core features** | 60+ |
| **Screens** | 22+ |
| **State management providers** | 6 |
| **Core services** | 30+ |
| **ML model classes** | 31 (29 plants + 2 OOD) |
| **Catalog plants** | 30 (29 model-aligned + Yerba Buena browse-only) |
| **DOH-approved plants** | 10 |
| **Supabase migrations** | 19 |
| **Languages supported** | 2 (English, Filipino) |
| **Training pipeline** | Modal T4 GPU, triggered from admin panel |

---

## Data Collection for Thesis Research

HerbaScan collects local data for academic research analysis:

- **User Feedback** — 5-star rating, 6 categories (Accuracy, Usability, Performance, Features, Bugs, General), comments, feature suggestions; stored in Supabase `user_feedback` (admin-viewable, user-insertable)
- **Performance Monitoring** — operation timing (app start, image capture, AI inference); average / min / max / median per operation; JSON export
- **Usage Analytics** — scan tracking (total, successful, failed, poor quality, no match), success rate, feature usage, most scanned plants, most searched conditions
- **Error Logging** — 8 error types (camera, AI, database, network, etc.), stack traces, context data, last-24h stats; Admin System Health provides filter/expand/export UI
- **Export** — JSON / Markdown / CSV / Plain Text from Admin System Health export sheet; clipboard copy + file download

---

## Offline Processing Capabilities

HerbaScan is designed for rural areas with limited connectivity:

- **Offline plant identification** — TFLite inference fully on-device; no backend call during scanning
- **Offline plant data** — full SQLite database with catalog, safety, habitat, anatomy, conditions
- **Offline XAI explanations** — `plant_explanations.json` bundled in APK; no LLM call
- **Offline safety assessment** — `safety_profiles.json` + SQLite `safety_profiles`
- **Automatic sync** — `CatalogSyncService` syncs Supabase → SQLite on launch when online
- **Offline indicator** — `OfflineProvider` monitors connectivity in real time

---

## Development Notes

### Design System

- **Theme file**: `lib/core/theme/app_theme.dart`
- **Primary**: Botanical Emerald `#16A34A` (light) / `#4ADE80` (dark)
- **Surfaces**: Soft Sage `#F4F7F4` (light scaffold) / Forest Black `#0F1714` (dark scaffold)
- **Cards (dark)**: Deep Slate-Green `#1C2B22`
- **Typography**: Inter variable font
- **Spacing**: 4 px base unit; consistent 12 / 16 / 24 px rhythm
- **Shapes**: `BorderRadius.circular(16)` for cards, `12` for buttons and inputs

### Known Constraints

| Item | Status | Notes |
| --- | --- | --- |
| Beta testing with real users | Pending | 50+ test cases documented |
| App Store / Google Play prep | Pending | APK builds successfully |
| 2D silhouette SVG data | Partial | Seed templates exist; real SVG paths needed per plant |
| Railway cold start latency | Acceptable | 10–30 s cold; 2–4 s warm |
| Supabase email rate limit | Dev only | 2 emails/hour; use custom SMTP for production |
| `SUPABASE_JWT_SECRET` | Resolved | Recommended unset |
| Live LLM / Gemini API | Removed | All explanations deterministic; thesis-defensible |
| GradCAM / CAM heatmap | Removed (v1.0.7) | Classification-only pipeline |

---

## Documentation

| File | Purpose |
| --- | --- |
| `README.md` | Project overview, setup, architecture (this file) |
| `setup.md` | Quick-start Flutter setup guide |
| `backend/README.md` | Complete backend documentation (Railway, model management, Postman) |
| `backend/QUICK_START.md` | 15-minute Railway deployment guide |
| `supabase/README.md` | Supabase setup, migrations, Edge Functions |
| `backend/HerbaScan_API.postman_collection.json` | Postman collection for backend API testing |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

---

## License

This project is part of an undergraduate thesis at Lyceum of the Philippines University-Cavite.

---

> **Note**: This app is for educational and informational purposes only. Always consult healthcare professionals before using any herbal remedies.
