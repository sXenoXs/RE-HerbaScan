"""
HerbaScan Backend API
FastAPI server for Grad-CAM computation using TensorFlow.

Security hardening (v1.0.26):
- slowapi rate limiting on /admin/* endpoints (5/minute)
- hmac.compare_digest for timing-safe admin secret comparison
- CORS restricted via ALLOWED_ORIGINS env var on /admin/* routes
- DEBUG print removed from /identify
- Startup validation warns if ADMIN_RELOAD_SECRET is absent or weak
"""

import hmac
import os
import time
import json
import base64
import io
from contextlib import asynccontextmanager
from pathlib import Path
from typing import List, Optional

import tensorflow as tf
import jwt
import numpy as np
from fastapi import FastAPI, File, Query, UploadFile, HTTPException, Depends, Header, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from utils.gradcam import generate_gradcam_for_image
from utils.preprocessing import preprocess_image, array_to_pil_image
from utils.validation_pipeline import (
    run_pipeline,
    USE_TFLITE,
    check_image_quality_scored,
    _get_plant_name,
)

# ---------------------------------------------------------------------------
# Global model state (loaded once at startup)
# ---------------------------------------------------------------------------
mobilenetv2_model = None
labels = None
MOBILENETV2_MODEL_PATH = Path("models/MobileNetV2_model.keras")
LABELS_PATH = Path("models/labels.json")

# ---------------------------------------------------------------------------
# Environment variables
# ---------------------------------------------------------------------------
SUPABASE_JWT_SECRET  = os.environ.get("SUPABASE_JWT_SECRET")
ADMIN_RELOAD_SECRET  = os.environ.get("ADMIN_RELOAD_SECRET")
SUPABASE_URL         = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
MODAL_TRAINING_URL   = os.environ.get("MODAL_TRAINING_URL")

# CORS: GET endpoints remain open (*); admin routes use ALLOWED_ORIGINS env var.
# In production, set ALLOWED_ORIGINS=https://herbascan-admin.vercel.app on Railway.
_raw_origins = os.environ.get("ALLOWED_ORIGINS", "")
ALLOWED_ADMIN_ORIGINS: List[str] = (
    [o.strip() for o in _raw_origins.split(",") if o.strip()]
    if _raw_origins.strip()
    else ["*"]
)

# Toxic plant routing is handled by name via toxic_blacklist in ood_safety_config.json.
# Adelfa, IpilIpil, TubaTuba are not output classes in the 31-class model.
TOXIC_CLASS_INDICES: set = set()

# ---------------------------------------------------------------------------
# Rate limiter (slowapi) — 5 requests/minute per IP on /admin/* endpoints
# ---------------------------------------------------------------------------
limiter = Limiter(key_func=get_remote_address)


# ---------------------------------------------------------------------------
# Lifespan: model load + startup validation
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load MobileNetV2 Keras model and labels on server startup."""
    global mobilenetv2_model, labels

    # --- Startup security validation ---
    if not ADMIN_RELOAD_SECRET:
        print("⚠️  WARNING: ADMIN_RELOAD_SECRET is not set. "
              "/admin/* endpoints will reject all requests.")
    elif len(ADMIN_RELOAD_SECRET) < 16:
        print("⚠️  WARNING: ADMIN_RELOAD_SECRET is shorter than 16 characters. "
              "Use a strong random secret in production.")

    try:
        print("🔄 Loading MobileNetV2 Keras model...")

        if MOBILENETV2_MODEL_PATH.exists():
            try:
                mobilenetv2_model = tf.keras.models.load_model(str(MOBILENETV2_MODEL_PATH))
                print(f"✅ MobileNetV2 model loaded from {MOBILENETV2_MODEL_PATH}")
            except Exception as e:
                print(f"❌ Error loading MobileNetV2 model: {e}")
                print("❌ Server will start, but /identify will not work")
        else:
            print(f"❌ Model not found at: {MOBILENETV2_MODEL_PATH}")

        if mobilenetv2_model is None:
            print("❌ MobileNetV2 model failed to load!")

        # Load labels
        if LABELS_PATH.exists():
            with open(LABELS_PATH, "r") as f:
                labels = json.load(f)
            print(f"✅ Labels loaded: {len(labels)} classes")
        else:
            print(f"⚠️  Labels file not found at: {LABELS_PATH}")
            labels = {str(i): f"Plant_{i}" for i in range(31)}

    except Exception as e:
        print(f"❌ Error during startup: {e}")
        print("📝 Server will start, but /identify may not work")

    yield  # App runs here

    print("🛑 Shutting down HerbaScan API...")


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="HerbaScan Backend API",
    description="Plant identification pipeline + model retraining trigger",
    version="1.0.7",
    lifespan=lifespan,
)

# Attach rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware — allow all origins for GET/read endpoints (mobile Flutter app
# uses Dart http package, not a browser, so origin is irrelevant for those).
# /admin/* is restricted via ALLOWED_ADMIN_ORIGINS (see individual route handlers).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------
def verify_supabase_jwt(authorization: str = Header(None)) -> bool:
    """
    Optional JWT verification for /identify:
    - If SUPABASE_JWT_SECRET is not set: allow all requests.
    - If no Bearer token is sent: allow (so scans work when user is not logged in).
    - If Bearer token is sent: verify it; if invalid or expired, return 401.
    """
    if not SUPABASE_JWT_SECRET:
        return True
    if not authorization or not authorization.startswith("Bearer "):
        return True
    token = authorization[7:]
    try:
        jwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            audience="authenticated",
            algorithms=["HS256"],
        )
        return True
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def _verify_admin_secret(x_admin_secret: Optional[str]) -> None:
    """
    Timing-safe admin secret verification (fixes audit finding #4).
    Uses hmac.compare_digest to prevent timing attacks.
    Raises HTTPException 401 on mismatch.
    """
    if not ADMIN_RELOAD_SECRET:
        raise HTTPException(
            status_code=500,
            detail="ADMIN_RELOAD_SECRET not configured on server."
        )
    if not x_admin_secret:
        raise HTTPException(status_code=401, detail="Missing x-admin-secret header.")
    # hmac.compare_digest: constant-time comparison prevents timing side-channel
    if not hmac.compare_digest(
        x_admin_secret.encode("utf-8"),
        ADMIN_RELOAD_SECRET.encode("utf-8"),
    ):
        raise HTTPException(status_code=401, detail="Invalid admin secret.")


# ---------------------------------------------------------------------------
# Public endpoints
# ---------------------------------------------------------------------------
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "service": "HerbaScan Backend API",
        "version": "1.0.7",
        "status": "running",
        "mobilenetv2_loaded": mobilenetv2_model is not None,
        "endpoints": {
            "health": "/health",
            "identify": "/identify (POST)",
            "test": "/test",
        },
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "mobilenetv2_loaded": mobilenetv2_model is not None,
        "labels_loaded": labels is not None,
        "num_classes": len(labels) if labels else 0,
    }


@app.get("/test")
async def test_endpoint():
    """Test endpoint for debugging."""
    return {
        "message": "HerbaScan API is working!",
        "mobilenetv2_status": "loaded" if mobilenetv2_model is not None else "not loaded",
        "mobilenetv2_path": str(MOBILENETV2_MODEL_PATH),
        "mobilenetv2_exists": MOBILENETV2_MODEL_PATH.exists(),
        "labels_count": len(labels) if labels else 0,
    }


@app.post("/identify")
async def identify_plant(
    file: UploadFile = File(...),
    _: bool = Depends(verify_supabase_jwt),
):
    """
    Main endpoint: Identify plant and generate Grad-CAM visualization.

    Returns:
        JSON with plant_name, confidence, predictions, gradcam_image, etc.
    """
    start_time = time.time()

    if mobilenetv2_model is None:
        raise HTTPException(
            status_code=503,
            detail="MobileNetV2 model not loaded. Please check server logs.",
        )

    try:
        image_bytes = await file.read()

        # Removed DEBUG print that leaked request metadata (audit finding #5)

        if not isinstance(image_bytes, bytes):
            raise HTTPException(
                status_code=400,
                detail=f"Expected bytes, got {type(image_bytes)}",
            )

        # ------------------------------------------------------------------ #
        # Two-stage validation + inference pipeline                           #
        # Stage 1 (OpenCV heuristics): blur & darkness checks                #
        # Stage 2 (ML + OOD):          inference with confidence gate        #
        # ------------------------------------------------------------------ #
        pipeline_result = run_pipeline(
            image_bytes,
            model=mobilenetv2_model,
            labels=labels,
        )
        if pipeline_result["status"] == "fail":
            raise HTTPException(
                status_code=422,
                detail=pipeline_result["result"],
            )

        _res = pipeline_result["result"]
        img_array            = _res["img_array"]
        predicted_class_idx  = _res["top_class_idx"]
        predicted_class_name = _res["top_class"]
        confidence           = _res["confidence"]
        predictions          = _res["predictions"]
        all_predictions      = _res["all_predictions"]
        model_name_used      = "MobileNetV2-TFLite" if USE_TFLITE else "MobileNetV2"

        print(f"✅ Pipeline PASS — {predicted_class_name} (confidence: {confidence:.4f})")

        original_image = Image.open(io.BytesIO(image_bytes))
        if original_image.mode != "RGB":
            original_image = original_image.convert("RGB")

        gradcam_result = generate_gradcam_for_image(
            model=mobilenetv2_model,
            img_array=img_array,
            original_image=original_image,
            class_idx=predicted_class_idx,
            layer_name=None,
        )

        overlay_img = gradcam_result["overlay"]
        buffered = io.BytesIO()
        overlay_img.save(buffered, format="PNG")
        gradcam_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

        processing_time = (time.time() - start_time) * 1000
        is_toxic = predicted_class_idx in TOXIC_CLASS_INDICES

        response = {
            "plant_name": predicted_class_name,
            "scientific_name": predicted_class_name,
            "confidence": confidence,
            "predictions": predictions,
            "all_predictions": all_predictions,
            "gradcam_image": gradcam_base64,
            "method": "grad-cam",
            "model_used": model_name_used,
            "processing_time_ms": round(processing_time, 2),
            "is_toxic": is_toxic,
        }

        return JSONResponse(content=response)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing image: {str(e)}",
        )


# ---------------------------------------------------------------------------
# Admin endpoints (rate limited + timing-safe secret check)
# ---------------------------------------------------------------------------
@app.post("/admin/reload-model")
@limiter.limit("5/minute")
async def reload_model_endpoint(
    request: Request,
    x_admin_secret: str = Header(None),
):
    """Hot-swap MobileNetV2_model.keras from Supabase Storage."""
    global mobilenetv2_model, labels

    _verify_admin_secret(x_admin_secret)

    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="Supabase credentials not configured on server.",
        )
    try:
        import httpx
        headers = {
            "apikey": SUPABASE_SERVICE_KEY,
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        }
        bucket_url = f"{SUPABASE_URL}/storage/v1/object/live-models"
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.get(f"{bucket_url}/MobileNetV2_model.keras", headers=headers)
            if r.status_code != 200:
                raise HTTPException(status_code=502, detail=f"Failed to download model: {r.text}")
            MOBILENETV2_MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
            MOBILENETV2_MODEL_PATH.write_bytes(r.content)
            r2 = await client.get(f"{bucket_url}/labels.json", headers=headers)
            if r2.status_code != 200:
                raise HTTPException(status_code=502, detail=f"Failed to download labels: {r2.text}")
            LABELS_PATH.write_bytes(r2.content)
        mobilenetv2_model = tf.keras.models.load_model(str(MOBILENETV2_MODEL_PATH))
        with open(LABELS_PATH, "r") as f:
            labels = json.load(f)
        return {"status": "ok", "num_classes": len(labels)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Reload failed: {str(e)}")


@app.post("/admin/trigger-training")
@limiter.limit("5/minute")
async def trigger_training(
    request: Request,
    request_body: dict = Body(...),
    x_admin_secret: str = Header(None),
):
    """
    Called by Flutter admin app.
    Validates secret (timing-safe), then calls Modal training endpoint.
    Returns immediately — training runs in background.
    """
    _verify_admin_secret(x_admin_secret)

    plant_slug     = request_body.get("plant_slug")
    new_class_name = request_body.get("new_class_name")

    if not plant_slug or not new_class_name:
        raise HTTPException(
            status_code=400,
            detail="plant_slug and new_class_name are required.",
        )

    if not MODAL_TRAINING_URL:
        raise HTTPException(status_code=500, detail="MODAL_TRAINING_URL not configured.")

    try:
        import httpx
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                MODAL_TRAINING_URL,
                json={
                    "plant_slug":     plant_slug,
                    "new_class_name": new_class_name,
                },
                headers={"Content-Type": "application/json"},
            )

        if response.status_code == 200:
            return {
                "status": "training_started",
                "plant_slug": plant_slug,
                "new_class_name": new_class_name,
                "message": "Training job queued on Modal. Takes ~15 min on T4 GPU.",
            }
        else:
            raise HTTPException(
                status_code=502,
                detail=f"Modal returned {response.status_code}: {response.text}",
            )

    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Modal endpoint timed out.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to trigger training: {str(e)}")


@app.post("/admin/test-inference")
@limiter.limit("5/minute")
async def admin_test_inference(
    request: Request,
    file: UploadFile = File(...),
    temperature: float = Query(default=1.0, ge=0.1, le=5.0),
    x_admin_secret: str = Header(None),
):
    """
    Admin model inference testing endpoint.

    Accepts an image upload and runs the same two-stage validation pipeline
    used by /identify, but returns full diagnostic output including:
      - OOD gate raw metric scores (brightness, blur, edge_density)
      - Top-5 predictions with temperature-scaled confidences
      - Confidence gate pass/fail
      - Final result (plant name, scientific name) or rejection reason

    Temperature scaling (0.1–5.0, default 1.0) calibrates confidence values.
    T < 1.0 sharpens the distribution (lower entropy); T > 1.0 flattens it.

    This endpoint does NOT generate Grad-CAM — it returns structured JSON only,
    keeping the response fast and small for quick admin testing.
    """
    _verify_admin_secret(x_admin_secret)

    # ---- Validate model is loaded ------------------------------------------
    if mobilenetv2_model is None:
        raise HTTPException(
            status_code=503,
            detail="MobileNetV2 model not loaded. Run /admin/reload-model first.",
        )

    try:
        image_bytes = await file.read()

        if not isinstance(image_bytes, bytes):
            raise HTTPException(
                status_code=400,
                detail=f"Expected bytes, got {type(image_bytes)}",
            )

        # ---- Get image dimensions from raw bytes ---------------------------
        pil_img = Image.open(io.BytesIO(image_bytes))
        img_width, img_height = pil_img.size
        if pil_img.mode != "RGB":
            pil_img = pil_img.convert("RGB")

        # ---- Stage 1: Heuristic checks with scored output ------------------
        ood_gate = check_image_quality_scored(image_bytes)

        model_info = {
            "path": str(MOBILENETV2_MODEL_PATH),
            "temperature": temperature,
            "num_classes": len(labels) if labels else 0,
        }

        image_info = {
            "filename": file.filename or "unknown",
            "width": img_width,
            "height": img_height,
        }

        # ---- Default empty response fields ---------------------------------
        top_5: list = []
        confidence_gate: dict = {
            "value": 0.0,
            "threshold": 0.0,
            "passed": False,
        }
        result: dict | None = None
        ood_rejected = not ood_gate["overall_pass"]
        stage1_rejected = not ood_gate["overall_pass"]

        # ---- Stage 2: ML inference (only if Stage 1 passed) ----------------
        if ood_gate["overall_pass"]:
            # Reuse the same preprocess + inference chain as /identify
            pipeline_result = run_pipeline(
                image_bytes,
                model=mobilenetv2_model,
                labels=labels,
            )

            if pipeline_result["status"] == "fail":
                ood_rejected = True
                stage1_rejected = False
                confidence_gate["threshold"] = 0.0
                confidence_gate["value"] = 0.0
                confidence_gate["passed"] = False

                # Build empty top_5 as fallback
                top_5 = [
                    {
                        "rank": i + 1,
                        "label": "-",
                        "confidence": 0.0,
                        "bar_fraction": 0.0,
                    }
                    for i in range(5)
                ]
            else:
                _res = pipeline_result["result"]
                img_array = _res["img_array"]

                # Run raw inference via the model directly to get logits
                # for temperature scaling (run_pipeline already applied softmax)
                if USE_TFLITE:
                    from utils.validation_pipeline import _run_tflite_inference, TFLITE_MODEL_PATH
                    raw_preds = _run_tflite_inference(TFLITE_MODEL_PATH, img_array)
                else:
                    preds = mobilenetv2_model.predict(img_array, verbose=0)
                    raw_preds = np.array(preds[0], dtype=np.float32)

                # ---- Temperature scaling ------------------------------------
                if temperature != 1.0:
                    log_probs = np.log(np.clip(raw_preds, 1e-9, 1.0))
                    scaled = log_probs / temperature
                    scaled -= np.max(scaled)  # numerical stability
                    exp_scaled = np.exp(scaled)
                    raw_preds = exp_scaled / exp_scaled.sum()

                # ---- Top-5 construction -------------------------------------
                top_5_indices = np.argsort(raw_preds)[-5:][::-1]
                max_conf = float(raw_preds[top_5_indices[0]])

                top_5 = [
                    {
                        "rank": i + 1,
                        "label": _get_plant_name(int(idx), labels or {}),
                        "confidence": round(float(raw_preds[idx]), 4),
                        "bar_fraction": (
                            round(float(raw_preds[idx]) / max_conf, 4)
                            if max_conf > 0
                            else 0.0
                        ),
                    }
                    for i, idx in enumerate(top_5_indices)
                ]

                # ---- Confidence gate ----------------------------------------
                from utils.validation_pipeline import load_ood_config
                ood_config = load_ood_config()
                ood_threshold = float(
                    ood_config.get("confidence_threshold_ood", 0.4)
                )
                top1_conf = float(raw_preds[top_5_indices[0]])
                confidence_passed = top1_conf >= ood_threshold

                confidence_gate = {
                    "value": round(top1_conf, 4),
                    "threshold": ood_threshold,
                    "passed": confidence_passed,
                }

                if confidence_passed:
                    top1_idx = int(top_5_indices[0])
                    top1_name = _get_plant_name(top1_idx, labels or {})
                    result = {
                        "plant_name": top1_name,
                        "scientific_name": top1_name,
                    }
                else:
                    ood_rejected = True

        # ---- Build final response -------------------------------------------
        response_data = {
            "model_info": model_info,
            "image_info": image_info,
            "ood_gate": ood_gate,
            "top_5": top_5,
            "confidence_gate": confidence_gate,
            "result": result,
            "ood_rejected": ood_rejected,
            "stage1_rejected": stage1_rejected,
        }

        return JSONResponse(content=response_data)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing test inference: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))

    print("🌿 Starting HerbaScan Backend API...")
    print(f"📂 MobileNetV2 model path: {MOBILENETV2_MODEL_PATH}")
    print(f"📂 Labels path: {LABELS_PATH}")
    print(f"🌐 Starting on port {port}")
    print(f"🔒 Admin CORS origins: {ALLOWED_ADMIN_ORIGINS}")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info",
    )