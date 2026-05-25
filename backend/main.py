"""
HerbaScan Backend API
FastAPI server for true Grad-CAM computation using TensorFlow
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Header, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import tensorflow as tf
import jwt
import numpy as np
import json
import base64
import io
import time
import os
from PIL import Image
from pathlib import Path

from utils.gradcam import generate_gradcam_for_image
from utils.preprocessing import preprocess_image, array_to_pil_image
from utils.validation_pipeline import run_pipeline, USE_TFLITE

# Global variables for models (loaded once at startup)
mobilenetv2_model = None
labels = None
MOBILENETV2_MODEL_PATH = Path("models/MobileNetV2_model.keras")
LABELS_PATH = Path("models/labels.json")
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
ADMIN_RELOAD_SECRET = os.environ.get("ADMIN_RELOAD_SECRET")
SUPABASE_URL        = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
MODAL_TRAINING_URL  = os.environ.get("MODAL_TRAINING_URL")

# Toxic plant routing is handled by name via toxic_blacklist in ood_safety_config.json.
# Adelfa, IpilIpil, TubaTuba are not output classes in the 31-class model.
TOXIC_CLASS_INDICES: set = set()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load MobileNetV2 Keras model and labels on server startup."""
    global mobilenetv2_model, labels

    try:
        print("🔄 Loading MobileNetV2 Keras model...")

        # Load MobileNetV2 model
        if MOBILENETV2_MODEL_PATH.exists():
            try:
                mobilenetv2_model = tf.keras.models.load_model(str(MOBILENETV2_MODEL_PATH))
                print(f"✅ MobileNetV2 model loaded successfully from {MOBILENETV2_MODEL_PATH}")
            except Exception as e:
                print(f"❌ Error loading MobileNetV2 model: {str(e)}")
                print("❌ Server will start, but /identify endpoint will not work")
        else:
            print(f"❌ MobileNetV2 model file not found at: {MOBILENETV2_MODEL_PATH}")
            print("❌ Please ensure MobileNetV2_model.keras exists in models/ directory")

        if mobilenetv2_model is None:
            print("❌ MobileNetV2 model failed to load! Please check the model file.")

        # Load labels
        if LABELS_PATH.exists():
            with open(LABELS_PATH, 'r') as f:
                labels = json.load(f)
            print(f"✅ Labels loaded: {len(labels)} classes")
        else:
            print(f"⚠️  Labels file not found at: {LABELS_PATH}")
            print("📝 Please place your labels.json file in the models/ directory")
            labels = {str(i): f"Plant_{i}" for i in range(31)}

    except Exception as e:
        print(f"❌ Error loading models: {str(e)}")
        print("📝 Server will start, but /identify endpoint will not work")

    yield  # App runs here

    # Shutdown logic (optional cleanup)
    print("🛑 Shutting down HerbaScan API...")


# Initialize FastAPI app
app = FastAPI(
    title="HerbaScan Grad-CAM API",
    description="True gradient-based plant identification with explainable AI",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "service": "HerbaScan Grad-CAM API",
        "version": "1.0.0",
        "status": "running",
        "mobilenetv2_loaded": mobilenetv2_model is not None,
        "models_loaded": mobilenetv2_model is not None,
        "endpoints": {
            "health": "/health",
            "identify": "/identify (POST)",
            "test": "/test"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "mobilenetv2_loaded": mobilenetv2_model is not None,
        "models_loaded": mobilenetv2_model is not None,
        "labels_loaded": labels is not None,
        "num_classes": len(labels) if labels else 0
    }


@app.get("/test")
async def test_endpoint():
    """Test endpoint for debugging."""
    return {
        "message": "HerbaScan API is working!",
        "mobilenetv2_status": "loaded" if mobilenetv2_model is not None else "not loaded",
        "mobilenetv2_path": str(MOBILENETV2_MODEL_PATH),
        "mobilenetv2_exists": MOBILENETV2_MODEL_PATH.exists(),
        "labels_count": len(labels) if labels else 0
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
            detail="MobileNetV2 model not loaded. Please check server logs."
        )

    try:
        image_bytes = await file.read()

        print(f"DEBUG: Received file '{file.filename}', content_type: {file.content_type}, "
              f"bytes type: {type(image_bytes)}, bytes len: {len(image_bytes) if isinstance(image_bytes, bytes) else 'N/A'}")

        if not isinstance(image_bytes, bytes):
            raise HTTPException(
                status_code=400,
                detail=f"Expected bytes, got {type(image_bytes)}"
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
        img_array            = _res["img_array"]          # reuse — no double inference
        predicted_class_idx  = _res["top_class_idx"]
        predicted_class_name = _res["top_class"]
        confidence           = _res["confidence"]
        predictions          = _res["predictions"]
        all_predictions      = _res["all_predictions"]
        model_name_used      = "MobileNetV2-TFLite" if USE_TFLITE else "MobileNetV2"

        print(f"✅ Pipeline PASS — {predicted_class_name} (confidence: {confidence:.4f})")

        original_image = Image.open(io.BytesIO(image_bytes))
        if original_image.mode != 'RGB':
            original_image = original_image.convert('RGB')

        gradcam_result = generate_gradcam_for_image(
            model=mobilenetv2_model,
            img_array=img_array,
            original_image=original_image,
            class_idx=predicted_class_idx,
            layer_name=None
        )

        overlay_img = gradcam_result['overlay']
        buffered = io.BytesIO()
        overlay_img.save(buffered, format="PNG")
        gradcam_base64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

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

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing image: {str(e)}"
        )


@app.post("/admin/reload-model")
async def reload_model_endpoint(x_admin_secret: str = Header(None)):
    global mobilenetv2_model, labels
    if not ADMIN_RELOAD_SECRET:
        raise HTTPException(status_code=500, detail="ADMIN_RELOAD_SECRET not configured on server.")
    if x_admin_secret != ADMIN_RELOAD_SECRET:
        raise HTTPException(status_code=401, detail="Invalid admin secret.")
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(status_code=500, detail="Supabase credentials not configured on server.")
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
async def trigger_training(
    request_body: dict = Body(...),
    x_admin_secret: str = Header(None),
):
    """
    Called by Flutter admin app.
    Validates secret, then calls Modal training endpoint.
    Returns immediately — training runs in background.
    """
    if not ADMIN_RELOAD_SECRET:
        raise HTTPException(status_code=500, detail="ADMIN_RELOAD_SECRET not configured.")
    if x_admin_secret != ADMIN_RELOAD_SECRET:
        raise HTTPException(status_code=401, detail="Invalid admin secret.")

    plant_slug     = request_body.get("plant_slug")
    new_class_name = request_body.get("new_class_name")

    if not plant_slug or not new_class_name:
        raise HTTPException(
            status_code=400,
            detail="plant_slug and new_class_name are required."
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
                "message": "Training job queued on Modal. Takes ~15 min on T4 GPU."
            }
        else:
            raise HTTPException(
                status_code=502,
                detail=f"Modal returned {response.status_code}: {response.text}"
            )

    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Modal endpoint timed out.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to trigger training: {str(e)}")


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))

    print("🌿 Starting HerbaScan Grad-CAM API...")
    print(f"📂 MobileNetV2 model path: {MOBILENETV2_MODEL_PATH}")
    print(f"📂 Labels path: {LABELS_PATH}")
    print(f"🌐 Starting on port {port}")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )