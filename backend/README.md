# HerbaScan Backend API

**Backend Version:** 1.0.7  
**Status:** Aligned with app v1.0.31 (31-class model)

> **Important Architecture Note:** HerbaScan is an **offline-first** application. Plant identification runs fully on-device via TFLite. The Flutter app does **not** call this backend during scanning. This Python FastAPI backend is a microservice used *exclusively* for triggering model retraining and performing model hot-reloads.

---

## 🚀 Deployment (Railway)

This backend is designed to be deployed on Railway. Since HerbaScan is a monorepo, configure your Railway service as follows:
- **Root Directory:** `backend`
- **Watch Path:** `backend/**` (Optional: so only backend changes trigger redeploys)
- The build and start scripts are automatically handled by `backend/railway.json`.

For a 15-minute quick start guide to Railway deployment, see `QUICK_START.md`.

---

## 🔑 Environment Variables

Set these in your Railway service variables:

| Variable | Required | Purpose |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | **Yes** | Shared secret for the `/admin` endpoints. Must match the Flutter app config. |
| `MODAL_TRAINING_URL` | **Yes** | Modal web endpoint triggered to start the GPU pipeline. |
| `SUPABASE_URL` | **Yes** | Required by `/admin/reload-model` to download the new `.keras` model. |
| `SUPABASE_SERVICE_KEY`| **Yes** | Required by `/admin/reload-model`. |
| `SUPABASE_JWT_SECRET` | No | **Leave unset** to allow anonymous testing of the `/identify` endpoint. |

---

## 📡 API Endpoints

| Method | Path | Auth Required | Description |
| --- | --- | --- | --- |
| `GET` | `/health` | None | Returns API info and model load status. |
| `POST` | `/admin/trigger-training` | `x-admin-secret` | Forwards the request to the Modal GPU pipeline to begin training. |
| `POST` | `/admin/reload-model` | `x-admin-secret` | Downloads the retrained `MobileNetV2_model.keras` and `labels.json` from the Supabase `live-models` bucket and hot-reloads it in memory. |
| `POST` | `/admin/test-inference` | `x-admin-secret` | Tests full Keras inference and returns scored OOD gate results for admin diagnostics. |

---

## 🧠 Regenerating TFLite Assets (Post-Retraining)

When the Keras model is successfully retrained via the Modal pipeline, you must regenerate the multi-output `.tflite` asset for the Flutter app.

1. Ensure the new `.keras` model is saved at `backend/models/MobileNetV2_model.keras`.
2. Run the conversion script from the `backend/` directory:
   ```bash
   python create_multi_output_tflite.py
   ```
3. Copy the resulting `mobilenetv2_multi_output.tflite` from `backend/models/` into `assets/models/`.
4. Ensure `assets/models/class_indices.json` remains perfectly in sync with `backend/models/labels.json`.
5. Rebuild the Flutter app.
