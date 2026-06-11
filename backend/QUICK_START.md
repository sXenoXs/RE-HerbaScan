# HerbaScan Backend — Quick Start Guide

**Last Updated**: June 11, 2026
**Backend Version**: 1.0.7 (31-class model; GradCAM/CAM system removed)
**Flutter App Version**: v1.0.28

> **Architecture note:** Plant identification runs **fully offline** on-device via TFLite. The Railway backend is used exclusively for model retraining (`POST /admin/trigger-training` → Modal GPU) and model hot-reload (`POST /admin/reload-model`). The `/identify` endpoint exists for server-side testing but is **not called by the Flutter app** during normal scanning.

---

## ✓ What's Complete

Your backend is **100% ready** to deploy. All code is written and tested.

```
✓ Python FastAPI backend code complete
✓ MobileNetV2 31-class model; Dockerfile and Railway config ready
✓ POST /admin/trigger-training — forwards training requests to Modal GPU pipeline
✓ POST /admin/reload-model — hot-swaps MobileNetV2_model.keras from Supabase Storage
✓ POST /admin/test-inference — tests model inference with scored OOD gate results
✓ Two-stage validation pipeline (blur / darkness / edge density + OOD confidence gate)
✓ API documentation complete (backend/README.md + HerbaScan_API.postman_collection.json)
```

---

## Prerequisites

Before deploying, make sure you have:

- ✓ Railway account ([railway.app](https://railway.app))
- ✓ GitHub account with access to the HerbaScan repo
- ✓ Model file in `backend/models/`:
  - `MobileNetV2_model.keras` — **required** for `/identify` and `/admin/reload-model`
  - `labels.json` — optional; 31 placeholder labels are auto-generated if absent

> **Label format note:** `backend/models/labels.json` uses `index → name` format. `assets/models/class_indices.json` (Flutter) uses `name → index` format. Both must stay in sync across any retraining run. See `backend/README.md` for details.

---

## Deploy in 3 Steps (15 minutes)

### Step 1: Connect the Repo to Railway

#### Option A: Monorepo (recommended — main HerbaScan repo)

This repo is already a monorepo (Flutter app at root, backend under `backend/`). In Railway:

1. Create a new service linked to the `sXenoXs/RE-HerbaScan` repo.
2. Open the service → **Settings → Source** → set **Root Directory** to `backend`.
3. Optionally set **Watch Path** to `backend/**` so only backend changes trigger redeploys.

Railway uses `backend/railway.json` (Dockerfile + start command) for build and deploy. No separate backend repo needed.

#### Option B: Separate backend repo

```bash
cd backend
git init
git add .
git commit -m "Initial commit: HerbaScan backend API"

# Create repo on GitHub: https://github.com/new (name: herbascan-backend)
git remote add origin https://github.com/YOUR_USERNAME/herbascan-backend.git
git push -u origin main
```

Then link that repo to a new Railway service (no Root Directory override needed).

### Step 2: Deploy to Railway

1. Go to [railway.app](https://railway.app)
2. Click **New Project** → **Deploy from GitHub repo**
3. Select your repository (and set Root Directory to `backend` if using the monorepo)
4. Railway detects the Dockerfile automatically and starts the build
5. Wait ~5–10 minutes for the first build

### Step 3: Get Your URL

1. In Railway dashboard → your service → **Settings → Networking**
2. Click **Generate Domain**
3. Copy your URL: `https://YOUR-APP.up.railway.app`

> **Production URL (already deployed):** `https://re-herbascan-production.up.railway.app`

---

## Required Environment Variables

Set these in Railway → your service → **Variables**:

| Variable | Required | Notes |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | **Yes** | Shared secret for `/admin/reload-model` and `/admin/trigger-training` — must match `trigger_training_widget.dart` |
| `MODAL_TRAINING_URL` | **Yes** | Modal web endpoint for training trigger |
| `SUPABASE_URL` | Yes (reload only) | Required by `/admin/reload-model` to download model from Storage |
| `SUPABASE_SERVICE_KEY` | Yes (reload only) | Required by `/admin/reload-model` |
| `SUPABASE_JWT_SECRET` | **Do not set** | Leave unset — prevents 401 for anonymous users on `/identify` |

---

## Test Your API

### Option A: Browser (quick)

```text
https://YOUR-APP.up.railway.app/health
```

Expected response when model is loaded:

```json
{
  "status": "healthy",
  "mobilenetv2_loaded": true,
  "labels_loaded": true,
  "num_classes": 31
}
```

### Option B: curl

```bash
# Health check
curl https://YOUR-APP.up.railway.app/health

# Test identification (server-side only — Flutter app does not call this)
curl -X POST https://YOUR-APP.up.railway.app/identify -F "file=@path/to/image.jpg"
```

> Use `curl` for Railway file upload tests — Postman can have multipart issues on Railway. Postman works fine for local testing.

### Option C: Postman

1. Open Postman → Import `backend/HerbaScan_API.postman_collection.json`
2. Update the `railway_url` collection variable to your Railway URL
3. Run **Health Check (Railway)** → confirm `"mobilenetv2_loaded": true`
4. Run **Identify Plant (Railway)** with a plant image

For full Postman instructions see `backend/README.md` → "Testing with Postman".

---

## Admin Training Trigger

The Railway backend is called from the Flutter admin panel to start model retraining:

```dart
// lib/features/admin/widgets/trigger_training_widget.dart
// Sends POST /admin/trigger-training with x-admin-secret header
// and {plant_slug, new_class_name} body.
// Training runs asynchronously on Modal GPU (~15 min) and auto-reloads the model.
```

The Railway URL is already wired in `lib/features/admin/widgets/trigger_training_widget.dart`.

---

## Updating Models

Use this workflow after a retraining run produces a new `.keras` model.

### Step 1 — Replace the Keras model

```bash
# Backup (optional)
cp backend/models/MobileNetV2_model.keras backend/models/MobileNetV2_model.keras.backup

# Place the retrained model
cp /path/to/retrained_model.keras backend/models/MobileNetV2_model.keras
```

### Step 2 — Update labels if class mappings changed

Both files must stay in sync — same 31 classes, same index assignments:

```bash
# Backend labels (index → name) — edit directly
# backend/models/labels.json

# Flutter labels (name → index) — edit directly
# assets/models/class_indices.json
```

### Step 3 — Test locally

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux

pip install -r requirements.txt
python main.py
curl http://localhost:8000/health
# Confirm "num_classes": 31
```

### Step 4 — Regenerate the Flutter TFLite asset

```bash
cd backend

# Create the multi-output TFLite (outputs: [1,7,7,1280] features + [1,31] predictions)
# If MODEL_PATH in the script still points to .h5, update it to .keras first:
#   MODEL_PATH = Path("models/MobileNetV2_model.keras")
python create_multi_output_tflite.py
# → backend/models/mobilenetv2_multi_output.tflite
```

> `extract_cam_weights.py` is **not used** — the GradCAM/CAM system was removed in v1.0.7. Do not run it or copy any `cam_weights` file to Flutter assets.

### Step 5 — Copy TFLite asset to Flutter and rebuild

```bash
# From project root
cp backend/models/mobilenetv2_multi_output.tflite assets/models/

# Rebuild Flutter app
flutter clean && flutter pub get && flutter run
```

`pubspec.yaml` already declares `assets/models/` as an asset path — no changes needed unless class mappings changed.

### Step 6 — Redeploy to Railway

```bash
git add backend/models/MobileNetV2_model.keras backend/models/labels.json
git commit -m "Update model to retrained v<version>"
git push
# Railway auto-redeploys on push
```

---

## Troubleshooting

| Issue | Cause | Fix |
| --- | --- | --- |
| `"mobilenetv2_loaded": false` on `/health` | Model file missing or failed to load | Verify `MobileNetV2_model.keras` exists in `backend/models/`; check Railway logs |
| 503 on `/identify` | Model not loaded at startup | Check model file path and Railway volume / Git LFS setup |
| 422 on `/identify` | Stage 1 or Stage 2 validation failure | Image is too blurry, too dark, featureless, or not a plant |
| 401 on `/admin/*` | Wrong or missing `x-admin-secret` header | Verify `ADMIN_RELOAD_SECRET` matches between `trigger_training_widget.dart` and Railway variable |
| 401 on `/identify` | `SUPABASE_JWT_SECRET` is set | Remove `SUPABASE_JWT_SECRET` from Railway Variables and redeploy |
| 502 on `/admin/trigger-training` | Modal endpoint error | Verify `MODAL_TRAINING_URL` is correct and Modal deployment is active |
| 502 on `/admin/reload-model` | Supabase Storage download failed | Check `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, and that `live-models` bucket exists |
| TFLite conversion fails | TensorFlow version incompatibility | Use `pip install tensorflow==2.15.0`; see `backend/README.md` → Troubleshooting |
| Build failed on Railway | Missing model file or Dockerfile issue | Check Railway logs; verify model is in git (< 100 MB) or use Railway volumes / Git LFS |
| Cold start 10–30 s | TensorFlow model loading on first request | Expected on Railway free tier; warm requests take 2–4 s |

**For full troubleshooting details, see `backend/README.md` → "Troubleshooting".**

---

## Expected Performance

| Endpoint | Response Time |
| --- | --- |
| `GET /health` | < 100 ms |
| `GET /test` | < 100 ms |
| `POST /identify` (warm) | 2–4 s (includes ML inference + Grad-CAM on server) |
| Cold start (first request) | 10–30 s (TensorFlow model load) |

---

## That's It

Once deployed, you have:

- ✓ Working model retraining pipeline (Modal GPU triggered via `/admin/trigger-training`)
- ✓ Model hot-reload endpoint (`/admin/reload-model` pulls from Supabase `live-models` bucket)
- ✓ 31-class MobileNetV2 model (29 plants + `Not_Plant` @ index 19 + `UnknownPlant` @ index 30)
- ✓ Plant identification runs **fully offline** on-device via TFLite — Railway is never called during scanning
- ✓ Offline XAI explanations for 30 catalog plants (29 ML classes + Yerba Buena browse-only)

### Next Steps

1. **Verify the deployment:**
   ```bash
   curl https://YOUR-RAILWAY-URL.railway.app/health
   # Expect: { "mobilenetv2_loaded": true, "labels_loaded": true, "num_classes": 31 }
   ```

2. **Test the admin training trigger** from the Flutter admin panel (Admin → Plant Metadata → Training Images → Trigger Training).

3. **Monitor performance** — check Railway logs for errors; upgrade to Railway Pro for production traffic.

---

## Quick Reference

### Local Development

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux

pip install -r requirements.txt

# Place MobileNetV2_model.keras in backend/models/ then run:
python main.py
# or: uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Verify
curl http://localhost:8000/health
```

### Railway Deployment

```bash
# Deploy (auto-deploys on git push to linked branch)
git push

# Stream logs
railway logs

# Get service URL
# Railway dashboard → service → Settings → Networking → Generate Domain
```

### After Retraining: Regenerate Flutter TFLite Asset

```bash
cd backend

# Regenerate TFLite from retrained Keras model
python create_multi_output_tflite.py
# → backend/models/mobilenetv2_multi_output.tflite

# Copy to Flutter assets
cp models/mobilenetv2_multi_output.tflite ../assets/models/

# Keep label maps in sync if classes changed:
# backend/models/labels.json        (index → name)
# assets/models/class_indices.json  (name → index)

# Rebuild Flutter app
flutter clean && flutter pub get && flutter run
```

---

**Ready to deploy? Follow the 3 steps above and your API will be live in 15 minutes.**
