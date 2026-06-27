# Backend Quick Start Guide

**Version**: 1.0.7
**Status**: Aligned with app v1.0.31

> **Note:** Plant identification runs **fully offline** on-device via TFLite. This backend is solely a microservice used for triggering Modal GPU retraining (`POST /admin/trigger-training`) and hot-swapping the new models (`POST /admin/reload-model`).

---

## Deploy to Railway in 3 Steps (15 minutes)

### Step 1: Connect to Railway
Because HerbaScan is a monorepo, you must tell Railway to look only at the `backend/` directory.

1. Go to [railway.app](https://railway.app) and click **New Project** → **Deploy from GitHub repo**.
2. Select the HerbaScan repository.
3. Open the new service's **Settings → Source** and set **Root Directory** to `backend`.

### Step 2: Set Environment Variables
Navigate to your service's **Variables** tab and add the following:

| Variable | Required | Purpose |
| --- | --- | --- |
| `ADMIN_RELOAD_SECRET` | **Yes** | Shared secret to authenticate `/admin` calls. Must match the Flutter app config. |
| `MODAL_TRAINING_URL` | **Yes** | Web endpoint for the Modal GPU pipeline. |
| `SUPABASE_URL` | **Yes** | Used by the reload-model endpoint. |
| `SUPABASE_SERVICE_KEY`| **Yes** | Used by the reload-model endpoint. |

> **Do NOT** set `SUPABASE_JWT_SECRET`. Leaving it unset allows anonymous testing of the endpoints without raising 401 errors.

### Step 3: Deploy & Verify
1. Wait ~5-10 minutes for the Railway build to finish.
2. In **Settings → Networking**, click **Generate Domain** (e.g., `https://YOUR-APP.up.railway.app`).
3. Verify the deployment:
   ```bash
   curl https://YOUR-APP.up.railway.app/health
   # Expected: {"status":"healthy","mobilenetv2_loaded":true,"labels_loaded":true,"num_classes":31}
   ```

You are now ready to trigger retraining jobs directly from the HerbaScan Flutter Admin Panel!
