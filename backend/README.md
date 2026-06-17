# HerbaScan Backend API

**Last Updated:** May 25, 2026
**Backend Version:** 1.0.7 (aligned with app v1.0.7 — 31-class model, Grad-CAM Flutter-side removed)

> **Architecture note:** Plant identification runs **fully offline** on-device via TFLite.
> The Flutter app does **not** call this backend during scanning.
> This backend is used exclusively for:
>
> - `POST /admin/trigger-training` → forwards to Modal GPU pipeline for model retraining
> - `POST /admin/reload-model` → hot-swaps `MobileNetV2_model.keras` from Supabase Storage

---

## Deploying on Railway (monorepo)

This repo is a monorepo (Flutter app at root, backend in `backend/`). To deploy only the backend on Railway:

1. **Create/link the service** to the repo (e.g. `sXenoXs/RE-HerbaScan`).
2. **Set Root Directory** (Railway UI only):
   - Open the **backend service** → **Settings** → **Source**.
   - Set **Root Directory** to `backend`.
   - Railway will then use only files under `backend/` for build and deploy.
3. **Config file path** (if Railway asks or you use config-as-code):
   - Set the path from **repo root**: `backend/railway.json`.
4. **Watch path** (optional): set to `backend/**` so only changes under `backend/` trigger redeploys.

Build and start are defined in `backend/railway.json` (Dockerfile + start command).

---

## Setup Instructions

### 1. Place Model Files

Place the following files in `backend/models/`:

```text
backend/models/
├── MobileNetV2_model.keras      ← Required for /identify and /admin/reload-model
├── labels.json                  ← Optional; 31 placeholder labels generated if absent
└── ood_safety_config.json       ← OOD thresholds (num_classes=31, not_plant_class_index=19)
```

**`MobileNetV2_model.keras`** — MobileNetV2 architecture model (`.keras` format). Required for inference on `/identify` and for the `reload-model` endpoint to function.

**`labels.json`** — Class labels in backend format (`index: name`). Optional — if absent, the server generates 31 placeholder labels (`Plant_0` … `Plant_30`) matching the 31-class model.

```json
{
  "0": "Akapulko",
  "1": "AloeVera",
  "2": "Ampalaya",
  "19": "Not_Plant",
  "30": "UnknownPlant"
}
```

> **Label format note:** Backend uses `index → name` (this file). Flutter uses `name → index` (`assets/models/class_indices.json`). Both must stay in sync — 31 classes, same mappings — when retraining.

**`ood_safety_config.json`** — OOD safety thresholds. Current aligned values:

```json
{
  "num_classes": 31,
  "not_plant_class_index": 19,
  "confidence_threshold_accept": 0.85,
  "confidence_threshold_ood": 0.4,
  "ood_blur_threshold": 15.0,
  "ood_darkness_threshold": 10.0,
  "ood_edge_density_min": 0.003,
  "toxic_blacklist": ["Adelfa", "IpilIpil", "TubaTuba"]
}
```

---

## Model Class Count: 31

The backend is aligned to the **31-class MobileNetV2 model**:

| Index | Class |
| --- | --- |
| 0–18 | 19 plant classes (Akapulko → NiyogNiyogan) |
| 19 | `Not_Plant` — explicit OOD class |
| 20–29 | 10 more plant classes (Oregano → TsaangGubat) |
| 30 | `UnknownPlant` — OOD fallback |

**`TOXIC_CLASS_INDICES`** is an empty set — Adelfa, IpilIpil, and TubaTuba are **not** output classes in the 31-class model. Toxic routing is handled by name via `toxic_blacklist` in `ood_safety_config.json` (and app-layer in Flutter's `toxic_plant_blacklist.dart`).

---

## Two-Stage Validation Pipeline (`utils/validation_pipeline.py`)

All image requests through `/identify` pass through a two-stage gate before inference.

### Stage 1 — Heuristic Gatekeeper (OpenCV)

Runs on raw bytes. The ML model is **never** called if Stage 1 fails.

| Check | Constant | Value | Reject condition |
| --- | --- | --- | --- |
| Blur (Variance of Laplacian) | `BLUR_THRESHOLD` | `15.0` | score < 15.0 |
| Darkness (mean grayscale intensity [0–255]) | `DARKNESS_THRESHOLD` | `10.0` | mean < 10.0 |
| Edge density (Canny fraction) | `EDGE_DENSITY_THRESHOLD` | `0.003` | fraction < 0.003 |

These thresholds match `ood_safety_config.json` (`ood_blur_threshold`, `ood_darkness_threshold`, `ood_edge_density_min`).

### Stage 2 — ML Inference + OOD Gate

- Preprocesses image to `(224, 224, 3)` with `[0, 1]` normalization.
- Runs Keras inference (or TFLite if `USE_TFLITE=true`).
- Rejects if `max_confidence < confidence_threshold_ood` (default `0.4`).
- Rejects if top class is `Not_Plant` (index 19).
- Accepted results route to Grad-CAM generation in `/identify`.

---

## API Endpoints

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/` | None | API info + model load status |
| `GET` | `/health` | None | `{ status, model_loaded, labels_loaded, num_classes }` |
| `GET` | `/test` | None | Debug / connectivity check |
| `POST` | `/identify` | Optional JWT | Plant ID with server-side Grad-CAM (not called by Flutter during normal scanning) |
| `POST` | `/admin/trigger-training` | `x-admin-secret` header | Validates secret, forwards to Modal GPU pipeline |
| `POST` | `/admin/reload-model` | `x-admin-secret` header | Downloads model + labels from Supabase Storage and hot-reloads |

### `POST /identify`

**Request:** `multipart/form-data`, field `file` (JPEG/PNG)

**Optional header:** `Authorization: Bearer <Supabase access token>`

**Response:**

```json
{
  "plant_name": "Lagundi",
  "scientific_name": "Lagundi",
  "confidence": 0.942,
  "predictions": [],
  "all_predictions": [
    { "class": "Lagundi", "class_index": 14, "confidence": 0.942 },
    { "class": "Malunggay", "class_index": 16, "confidence": 0.031 },
    { "class": "Oregano", "class_index": 20, "confidence": 0.012 }
  ],
  "gradcam_image": "<base64-encoded PNG>",
  "method": "grad-cam",
  "processing_time_ms": 2341.78,
  "is_toxic": false
}
```

**`is_toxic`** — Always `false` because `TOXIC_CLASS_INDICES` is an empty set. Toxic plants (Adelfa, IpilIpil, TubaTuba) are not output classes in the 31-class model; toxic routing uses name matching via `ood_safety_config.json`.

**503 response** — Returned when `MobileNetV2_model.keras` failed to load at startup.

**422 response** — Returned when Stage 1 or Stage 2 validation fails.

### `POST /admin/trigger-training`

**Required header:** `x-admin-secret: <ADMIN_RELOAD_SECRET>`

**Request body:**

```json
{
  "plant_slug": "sambong-001",
  "new_class_name": "Sambong"
}
```

**Response:**

```json
{
  "status": "training_started",
  "plant_slug": "sambong-001",
  "new_class_name": "Sambong",
  "message": "Training job queued on Modal. Takes ~15 min on T4 GPU."
}
```

Returns immediately — training runs asynchronously on Modal GPU.

### `POST /admin/reload-model`

**Required header:** `x-admin-secret: <ADMIN_RELOAD_SECRET>`

Downloads `MobileNetV2_model.keras` and `labels.json` from Supabase Storage bucket `live-models` and hot-swaps them in memory without restarting the server.

**Required Railway env vars for this endpoint:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`.

### JWT Behaviour (`SUPABASE_JWT_SECRET` env var)

| Scenario | Behaviour |
| --- | --- |
| `SUPABASE_JWT_SECRET` not set **(recommended)** | All requests allowed (anonymous + signed-in) |
| Set, no Bearer header | Request allowed |
| Set, valid Bearer token | Request allowed |
| Set, invalid/expired token | 401 returned |

**Recommendation:** Leave `SUPABASE_JWT_SECRET` unset. The Flutter app does not call `/identify` during normal scanning, but setting this incorrectly would break any direct API calls from the admin or testing tools.

---

## Environment Variables

| Variable | Required | Notes |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | **Yes** | Shared secret for `/admin/reload-model` and `/admin/trigger-training` |
| `MODAL_TRAINING_URL` | **Yes** | Modal web endpoint for training trigger |
| `SUPABASE_URL` | Yes (reload only) | Required by `/admin/reload-model` to download model from Storage |
| `SUPABASE_SERVICE_KEY` | Yes (reload only) | Required by `/admin/reload-model` |
| `PORT` | Optional | Railway injects automatically; default `8000` |
| `SUPABASE_JWT_SECRET` | **Not recommended** | Leave unset — prevents 401 for anonymous users on `/identify` |
| `USE_TFLITE` | Optional | Set `true` to use TFLite interpreter instead of Keras in `validation_pipeline.py` |

---

## Local Development

```bash
# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux

# Install dependencies
pip install -r requirements.txt

# Place MobileNetV2_model.keras in backend/models/
python main.py
# Or:
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Verify
curl http://localhost:8000/health
```

**Expected `/health` response when model is loaded:**

```json
{
  "status": "healthy",
  "mobilenetv2_loaded": true,
  "labels_loaded": true,
  "num_classes": 31
}
```

---

## Updating Models After Retraining

When the Keras model is retrained via the Modal pipeline, regenerate the Flutter TFLite asset:

### Step 1: Replace the Keras model

```bash
# Backup (optional)
cp backend/models/MobileNetV2_model.keras backend/models/MobileNetV2_model.keras.backup

# Place the new retrained model
cp /path/to/retrained_model.keras backend/models/MobileNetV2_model.keras
```

### Step 2: Update labels if class mappings changed

```bash
# Backend labels (index → name)
# Edit backend/models/labels.json

# Flutter labels (name → index) — keep both in sync
# Edit assets/models/class_indices.json
```

### Step 3: Test locally

```bash
python main.py
curl http://localhost:8000/health
# Confirm "num_classes": 31
```

### Step 4: Regenerate the Flutter TFLite asset

```bash
cd backend

# Create multi-output TFLite (outputs: [1,7,7,1280] features + [1,31] predictions)
# If MODEL_PATH in the script still points to .h5, update it to .keras first:
#   MODEL_PATH = Path("models/MobileNetV2_model.keras")
python create_multi_output_tflite.py
# → backend/models/mobilenetv2_multi_output.tflite
```

> **Note:** `extract_cam_weights.py` is **no longer needed** — GradCAM/CAM weights were removed in v1.0.7. Do not run it or copy `mobilenetv2_cam_weights.json` to Flutter assets.

### Step 5: Copy to Flutter assets and rebuild

```bash
# From project root
cp backend/models/mobilenetv2_multi_output.tflite assets/models/

# Rebuild Flutter app
flutter clean && flutter pub get && flutter run
```

### Model compatibility requirements

| Parameter | Requirement |
| --- | --- |
| Input shape | `(224, 224, 3)` |
| Output shape | `(num_classes,)` — currently 31 |
| Architecture | Must have at least one convolutional layer |
| Format | `.keras` (TensorFlow Keras SavedModel format) |

**TensorFlow version note:** TFLite conversion works reliably with TensorFlow 2.15.0 or 2.13.0. Avoid TensorFlow 3.x.

---

## Testing with Postman

**Collection file:** `backend/HerbaScan_API.postman_collection.json`

**Included endpoints:** Health Check (Local/Railway), Root, Test, Identify Plant (Local/Railway)

**Variables:** `base_url` (localhost:8000), `railway_url` (your Railway URL)

### Quick test with curl

```bash
# Local
curl http://localhost:8000/health
curl -X POST http://localhost:8000/identify -F "file=@path/to/image.jpg"

# Railway
curl https://re-herbascan-production.up.railway.app/health
curl -X POST https://re-herbascan-production.up.railway.app/identify -F "file=@path/to/image.jpg"
```

> **Note:** Use `curl` for Railway file upload tests — Postman may have multipart issues on Railway. Postman works fine for local testing.

---

## Troubleshooting

| Issue | Cause | Fix |
| --- | --- | --- |
| `"model_loaded": false` on `/health` | Model file missing or failed to load | Check that `MobileNetV2_model.keras` exists in `backend/models/`; check Railway logs |
| 503 on `/identify` | Model not loaded at startup | Verify model file path and Railway volume/LFS setup |
| 422 on `/identify` | Stage 1 or Stage 2 validation failure | Image is too blurry, too dark, featureless, or not a plant |
| 401 on `/admin/*` | Wrong or missing `x-admin-secret` header | Verify `ADMIN_RELOAD_SECRET` matches between Flutter widget and Railway variable |
| 401 on `/identify` | `SUPABASE_JWT_SECRET` is set and token is invalid | Remove `SUPABASE_JWT_SECRET` from Railway Variables; redeploy |
| 502 on `/admin/trigger-training` | Modal endpoint returned error | Check `MODAL_TRAINING_URL` is correct and Modal deployment is active |
| 502 on `/admin/reload-model` | Supabase Storage download failed | Check `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, and that `live-models` bucket exists |
| TFLite conversion fails | TensorFlow version incompatibility | Use `pip install tensorflow==2.15.0` |
| Cold start 10–30 s | TensorFlow model loading on first request | Expected on Railway free tier; warm requests take 2–4 s |

### Model file size on Railway

If `MobileNetV2_model.keras` is larger than 100 MB, do not commit it directly to git. Use one of:

- **Git LFS** — `git lfs track "*.keras"` then commit normally
- **Railway Volumes** — upload via Railway CLI: `railway volumes upload models/MobileNetV2_model.keras`
- **Supabase Storage** — upload to `live-models` bucket; use `POST /admin/reload-model` to pull it to the running server

---

## Performance Expectations

| Metric | Typical |
| --- | --- |
| Cold start (TF model load) | 10–30 s |
| Warm inference + Grad-CAM | 2–4 s |
| Memory usage | 300–450 MB |
| `/health` / `/test` | < 100 ms |

---

## Railway Pricing

- **Hobby plan:** ~$5/month for low-traffic usage (model retraining triggers are infrequent)
- **Free tier:** $5 credit/month, 500 hours execution — sufficient for development and thesis testing
