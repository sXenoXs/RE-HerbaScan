"""
HerbaScan Backend — Two-Stage Image Validation & Inference Pipeline

Implements a strict gate before ML inference:
  Stage 1 (Heuristic Gatekeeper): OpenCV-based blur and darkness checks on raw
            image bytes — model is never called if Stage 1 fails.
  Stage 2 (ML Inference + OOD):   Preprocessing → model prediction → confidence
            threshold enforcement via ood_safety_config.json.

Entry point:
    run_pipeline(image_input, model=None, labels=None)
    → {"status": "pass" | "fail", "result": predictions_dict | error_str}

Standalone usage:
    python backend/utils/validation_pipeline.py /path/to/image.jpg
    Exits 0 on pass, 1 on fail.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from pathlib import Path
from typing import Union

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Re-use existing preprocessing utility
# ---------------------------------------------------------------------------
# When imported as part of the backend package (FastAPI), the path is already
# on sys.path via the backend/ root.  When run as a standalone script from
# anywhere else, we add the backend/ directory explicitly.
_BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

from utils.preprocessing import preprocess_image  # noqa: E402

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger(__name__)

# ===========================================================================
# CONSTANTS — all thresholds and paths live here; nothing is magic-numbered
# ===========================================================================

# --- Stage 1 thresholds ---
# Blur: Variance of Laplacian on grayscale image.  Images whose sharpness score
# falls below this threshold are rejected before inference.
# Matches ood_safety_config.json ood_blur_threshold and algorithm spec.
BLUR_THRESHOLD: float = 15.0

# Darkness: Mean pixel intensity of the grayscale image in the raw [0, 255] scale.
# Images with a mean below this are considered too dark and are rejected.
# Matches ood_safety_config.json ood_darkness_threshold and algorithm spec.
# VALIDATE: mean ~5 → 5 < 10 → rejected ✓
DARKNESS_THRESHOLD: float = 10.0

# Edge density: Fraction of pixels with Canny edge magnitude above zero.
# Images with fewer structural edges than this are featureless (plain background,
# solid colour) and are rejected before inference.
# Matches ood_safety_config.json ood_edge_density_min.
EDGE_DENSITY_THRESHOLD: float = 0.003

# --- File paths (all relative to backend/) ---
# Location relative to project root: /backend/models/ood_safety_config.json
OOD_CONFIG_PATH: Path = _BACKEND_DIR / "models" / "ood_safety_config.json"

# Location relative to project root: /backend/models/mobilenetv2_multi_output.tflite
TFLITE_MODEL_PATH: Path = _BACKEND_DIR / "models" / "mobilenetv2_multi_output.tflite"

# Location relative to project root: /backend/models/MobileNetV2_model.keras
KERAS_MODEL_PATH: Path = _BACKEND_DIR / "models" / "MobileNetV2_model.keras"

# Location relative to project root: /backend/models/labels.json
LABELS_PATH: Path = _BACKEND_DIR / "models" / "labels.json"

# --- Runtime mode ---
# Set USE_TFLITE=true in the environment to use tf.lite.Interpreter instead
# of a Keras model.  Default is Keras (Railway deployment).
USE_TFLITE: bool = os.getenv("USE_TFLITE", "false").lower() == "true"

# --- Error message strings (centralised so Flutter can match them exactly) ---
_ERR_CORRUPT = "Validation Failed: Image could not be decoded."
_ERR_BLUR    = "Validation Failed: Image is too blurry."
_ERR_DARK    = "Validation Failed: Image is too dark."
_ERR_EDGE    = "Validation Failed: Image lacks sufficient structure."
_ERR_OOD     = "Validation Failed: Subject unrecognized or not a plant."

# --- Default OOD config used when the JSON file is missing or malformed ---
_DEFAULT_OOD_CONFIG: dict = {
    "confidence_threshold_accept": 0.6,
    "confidence_threshold_ood": 0.4,
    "not_plant_class": "Not_Plant",
    "not_plant_class_index": -1,   # -1 = feature disabled
    "toxic_blacklist": ["Adelfa", "IpilIpil", "TubaTuba"],
}

# Module-level singleton cache for the OOD config so we only hit disk once.
_ood_config_cache: dict | None = None


# ===========================================================================
# STAGE 1 — HEURISTIC GATEKEEPER (OpenCV)
# ===========================================================================

def _decode_image_bgr(image_bytes: bytes) -> np.ndarray | None:
    """
    Decode raw image bytes into an OpenCV BGR array.

    Args:
        image_bytes: Raw bytes for a JPEG, PNG, BMP, WEBP, or similar image.

    Returns:
        np.ndarray of shape (H, W, 3) in BGR colour space, or None if decoding
        fails (e.g. corrupted buffer, unsupported format).
    """
    if not image_bytes:
        return None
    buf = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    return img  # None if cv2 could not decode


def check_image_quality(
    image_bytes: bytes,
    blur_threshold: float = BLUR_THRESHOLD,
    darkness_threshold: float = DARKNESS_THRESHOLD,
    edge_density_threshold: float = EDGE_DENSITY_THRESHOLD,
) -> tuple[bool, str]:
    """
    Stage 1 heuristic gatekeeper — runs entirely on raw bytes via OpenCV.
    The ML model is **never** invoked if this function returns False.

    Checks performed (in order):
      1. Image decodability (guard against corrupted uploads)
      2. Blur — Variance of Laplacian on grayscale
      3. Darkness — raw mean grayscale pixel intensity in [0, 255]

    Args:
        image_bytes:       Raw image bytes (JPEG, PNG, etc.).
        blur_threshold:    Minimum acceptable Variance of Laplacian score.
                           Below this → image considered too blurry.
                           Default: BLUR_THRESHOLD (100.0).
        darkness_threshold: Minimum acceptable mean grayscale intensity [0, 255].
                           Below this → image considered too dark.
                           Default: DARKNESS_THRESHOLD (40.0).
                           VALIDATE: mean ~10 → 10 < 40 → rejected ✓

    Returns:
        tuple (passed: bool, error_message: str)
          • (True,  "")           — all checks passed; proceed to Stage 2.
          • (False, _ERR_CORRUPT) — image bytes could not be decoded.
          • (False, _ERR_BLUR)    — image is too blurry.
          • (False, _ERR_DARK)    — image is too dark.

    Failure conditions:
        • Empty or None bytes → (False, _ERR_CORRUPT)
        • cv2.imdecode returns None → (False, _ERR_CORRUPT)
        • lap_var < blur_threshold → (False, _ERR_BLUR)
        • gray.mean() < darkness_threshold → (False, _ERR_DARK)
    """
    # ---- 0. Decode --------------------------------------------------------
    bgr = _decode_image_bgr(image_bytes)
    if bgr is None:
        logger.warning("Stage 1: image could not be decoded by OpenCV.")
        return False, _ERR_CORRUPT

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    # ---- 1. Blur check (Variance of Laplacian) ----------------------------
    lap_var: float = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    logger.debug("Stage 1 blur score (Var of Laplacian): %.2f (threshold: %.1f)",
                 lap_var, blur_threshold)
    if lap_var < blur_threshold:
        logger.info("Stage 1 REJECT — blur score %.2f < threshold %.1f",
                    lap_var, blur_threshold)
        return False, _ERR_BLUR

    # ---- 2. Darkness check (raw mean pixel intensity [0, 255]) ------------
    # DARKNESS_THRESHOLD = 40 → values below 40/255 ≈ 15.7% brightness are dark.
    # No normalisation needed; gray.mean() is already in [0, 255].
    mean_intensity: float = float(gray.mean())
    logger.debug("Stage 1 darkness score (raw mean): %.1f (threshold: %.1f)",
                 mean_intensity, darkness_threshold)
    if mean_intensity < darkness_threshold:
        logger.info("Stage 1 REJECT — darkness score %.1f < threshold %.1f",
                    mean_intensity, darkness_threshold)
        return False, _ERR_DARK

    # ---- 3. Edge density check (Canny) ---------------------------------------
    # Fraction of pixels that are Canny edges.  Featureless images (blank walls,
    # solid backgrounds) have almost no edges and are useless for inference.
    edges = cv2.Canny(gray, 50, 150)
    edge_density: float = float(np.sum(edges > 0)) / float(gray.size)
    logger.debug("Stage 1 edge density: %.5f (threshold: %.3f)",
                 edge_density, edge_density_threshold)
    if edge_density < edge_density_threshold:
        logger.info(
            "Stage 1 REJECT — edge density %.5f < threshold %.3f",
            edge_density, edge_density_threshold,
        )
        return False, _ERR_EDGE

    logger.debug("Stage 1 PASS — blur=%.2f, brightness=%.1f, edge=%.5f",
                 lap_var, mean_intensity, edge_density)
    return True, ""


# ===========================================================================
# OOD CONFIG LOADER (singleton)
# ===========================================================================

def load_ood_config() -> dict:
    """
    Load the OOD safety configuration from OOD_CONFIG_PATH, with caching.

    The config is read once and stored in a module-level cache.  Subsequent
    calls return the cached value without touching the filesystem.

    Returns:
        dict with at minimum the keys present in _DEFAULT_OOD_CONFIG.
        Any fields absent from the file are filled in from the defaults.

    Failure conditions:
        • File missing → logs a warning and returns _DEFAULT_OOD_CONFIG.
        • File present but invalid JSON → logs an error and returns defaults.
        • Any other I/O error → logs an error and returns defaults.

    Note:
        The fields `ood_blur_threshold` and `ood_darkness_threshold` that may
        appear in the config file are intentionally ignored here.  Stage 1
        thresholds are governed by the BLUR_THRESHOLD / DARKNESS_THRESHOLD
        constants (those config fields were generated with a different scale).
    """
    global _ood_config_cache
    if _ood_config_cache is not None:
        return _ood_config_cache

    config = dict(_DEFAULT_OOD_CONFIG)  # start from defaults

    if not OOD_CONFIG_PATH.exists():
        logger.warning(
            "OOD config not found at %s — using built-in defaults. "
            "Place ood_safety_config.json at backend/models/ to override.",
            OOD_CONFIG_PATH,
        )
        _ood_config_cache = config
        return config

    try:
        with OOD_CONFIG_PATH.open("r", encoding="utf-8") as fh:
            loaded: dict = json.load(fh)
        config.update(loaded)          # file values override defaults
        logger.info("OOD config loaded from %s", OOD_CONFIG_PATH)
    except json.JSONDecodeError as exc:
        logger.error(
            "OOD config at %s is malformed JSON (%s) — using defaults.",
            OOD_CONFIG_PATH, exc,
        )
    except OSError as exc:
        logger.error(
            "Could not read OOD config at %s (%s) — using defaults.",
            OOD_CONFIG_PATH, exc,
        )

    _ood_config_cache = config
    return config


# ===========================================================================
# STAGE 2 — ML INFERENCE & OOD ENFORCEMENT
# ===========================================================================

def _get_plant_name(idx: int, labels: dict) -> str:
    """
    Reverse-lookup a plant name from a label dict keyed by name → index.

    Args:
        idx:    Integer class index returned by the model.
        labels: dict {"PlantName": class_index, ...}

    Returns:
        Plant name string, or "Plant_<idx>" if the index is not found.
    """
    for name, class_idx in labels.items():
        if int(class_idx) == idx:
            return name
    return f"Plant_{idx}"


def _run_keras_inference(model, img_array: np.ndarray) -> np.ndarray:
    """
    Run a single forward pass through a loaded Keras model.

    Args:
        model:     Loaded tf.keras.Model instance.
        img_array: Preprocessed image array of shape [1, 224, 224, 3] in [0, 1].

    Returns:
        1-D numpy array of raw prediction scores (length = num_classes).

    Raises:
        RuntimeError: If the model is None or inference raises an exception.
    """
    if model is None:
        raise RuntimeError("Keras model is not loaded.")
    preds = model.predict(img_array, verbose=0)
    return np.array(preds[0], dtype=np.float32)


def _run_tflite_inference(tflite_model_path: Path, img_array: np.ndarray) -> np.ndarray:
    """
    Run inference via tf.lite.Interpreter on a multi-output TFLite model.

    The multi-output model exposes two output tensors:
      • 4-D feature maps  [1, H, W, C]   — used by offline CAM in Flutter
      • 2-D predictions   [1, num_classes] — used here

    The predictions tensor is identified by rank (ndim == 2) so output order
    does not matter.

    Args:
        tflite_model_path: Path to the .tflite model file.
        img_array:         Preprocessed image array [1, 224, 224, 3] in [0, 1].

    Returns:
        1-D numpy array of raw prediction scores (length = num_classes).

    Raises:
        FileNotFoundError: If the .tflite model file does not exist.
        RuntimeError:      If no 2-D output tensor can be found in the model.
    """
    if not tflite_model_path.exists():
        raise FileNotFoundError(
            f"TFLite model not found at {tflite_model_path}. "
            "Run re_export_models.py to generate it."
        )

    import tensorflow as tf  # import here to keep startup cost in main process

    interpreter = tf.lite.Interpreter(model_path=str(tflite_model_path))
    interpreter.allocate_tensors()

    input_details  = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]["index"], img_array.astype(np.float32))
    interpreter.invoke()

    # Pick the 2-D output as predictions (rank-2 tensor = [1, num_classes])
    pred_tensor = None
    for detail in output_details:
        out = interpreter.get_tensor(detail["index"])
        if out.ndim == 2:
            pred_tensor = out
            break

    if pred_tensor is None:
        raise RuntimeError(
            "TFLite model has no 2-D output tensor. "
            "Expected outputs: [1, 7, 7, 1280] (feature maps) and [1, N] (predictions)."
        )

    return np.array(pred_tensor[0], dtype=np.float32)


def run_inference(
    image_bytes: bytes,
    model,
    labels: dict,
    ood_config: dict,
) -> tuple[bool, dict | str]:
    """
    Stage 2: Preprocess the image, run ML inference, and enforce OOD thresholds.

    This function is only called after Stage 1 has passed.  It preprocesses the
    raw bytes, runs the model, checks the top-1 confidence against the OOD
    threshold, optionally checks for an explicit "not_plant" class, and builds
    the predictions payload that main.py will use to generate Grad-CAM.

    Args:
        image_bytes: Raw image bytes (already validated by Stage 1).
        model:       Loaded Keras model or None (TFLite path used when USE_TFLITE
                     is True; model arg is ignored for TFLite).
        labels:      Label mapping dict {"PlantName": class_index, ...}.
        ood_config:  Loaded OOD safety config (from load_ood_config()).

    Returns:
        tuple (passed: bool, result)
          • (True,  result_dict) — inference passed OOD gate.
          • (False, error_str)   — rejected; error_str is user-facing.

        result_dict keys (on pass):
            top_class       (str)          — top predicted plant name
            top_class_idx   (int)          — class index of top prediction
            confidence      (float)        — top-1 confidence score in [0, 1]
            predictions     (list[dict])   — top-3 in Flutter-expected format
            all_predictions (list[dict])   — top-3 in compact format
            img_array       (np.ndarray)   — preprocessed [1,224,224,3] array;
                                             reused by Grad-CAM in main.py
            routing_decision (str)         — "accepted" | "low_confidence" |
                                             "no_match" | "toxic_warning"

    Failure conditions:
        • max_confidence < ood_config["confidence_threshold_ood"] → (False, _ERR_OOD)
          VALIDATE: max_confidence=0.3, ood_threshold=0.4 → 0.3 < 0.4 → rejected ✓
          (Also valid for ood_threshold=0.6 → 0.3 < 0.6 → rejected ✓)
        • not_plant_class has highest confidence (if enabled) → (False, _ERR_OOD)
        • Preprocessing raises ValueError → (False, "Validation Failed: …")
        • Inference raises any exception → (False, "Validation Failed: Inference error: …")

    Config keys used:
        confidence_threshold_ood    — OOD rejection gate (default 0.4)
        confidence_threshold_accept — accepted/low-confidence routing (default 0.6)
        not_plant_class_index       — explicit not-plant class index (-1 = disabled)
    """
    ood_threshold     = float(ood_config.get("confidence_threshold_ood", 0.4))
    accept_threshold  = float(ood_config.get("confidence_threshold_accept", 0.6))
    not_plant_idx     = int(ood_config.get("not_plant_class_index", -1))

    # ---- Preprocess --------------------------------------------------------
    try:
        img_array = preprocess_image(image_bytes, target_size=(224, 224))
    except (ValueError, Exception) as exc:
        logger.error("Stage 2 preprocessing error: %s", exc)
        return False, f"Validation Failed: {exc}"

    # ---- Inference ---------------------------------------------------------
    try:
        if USE_TFLITE:
            logger.debug("Stage 2: running TFLite inference.")
            preds = _run_tflite_inference(TFLITE_MODEL_PATH, img_array)
        else:
            logger.debug("Stage 2: running Keras inference.")
            preds = _run_keras_inference(model, img_array)
    except FileNotFoundError as exc:
        logger.error("Stage 2 model missing: %s", exc)
        return False, "Validation Failed: Model not available."
    except RuntimeError as exc:
        logger.error("Stage 2 runtime error: %s", exc)
        return False, f"Validation Failed: Inference error: {exc}"
    except Exception as exc:
        logger.exception("Stage 2 unexpected inference error.")
        return False, f"Validation Failed: Inference error: {exc}"

    max_idx  = int(np.argmax(preds))
    max_conf = float(preds[max_idx])

    logger.debug("Stage 2 top-1: class=%d, confidence=%.4f (OOD threshold=%.2f)",
                 max_idx, max_conf, ood_threshold)

    # ---- Optional not_plant class check ------------------------------------
    # Only active when not_plant_class_index is within the model's class range.
    if 0 <= not_plant_idx < len(preds):
        not_plant_conf = float(preds[not_plant_idx])
        if max_idx == not_plant_idx:
            logger.info(
                "Stage 2 REJECT — not_plant class is top prediction "
                "(confidence=%.4f).", not_plant_conf
            )
            return False, _ERR_OOD

    # ---- OOD confidence gate -----------------------------------------------
    # Reads confidence_threshold_ood from ood_safety_config.json (default 0.4).
    # VALIDATE: max_conf=0.3, ood_threshold=0.4 → 0.3 < 0.4 → rejected ✓
    # VALIDATE: config missing → load_ood_config() returns default (0.4), no crash ✓
    # VALIDATE: USE_TFLITE=True → _run_tflite_inference() used exclusively ✓
    if max_conf < ood_threshold:
        logger.info(
            "Stage 2 REJECT — max confidence %.4f < OOD threshold %.2f.",
            max_conf, ood_threshold,
        )
        return False, _ERR_OOD

    # ---- Build predictions payload -----------------------------------------
    top_3_indices = np.argsort(preds)[-3:][::-1]

    predictions: list[dict] = []
    all_predictions: list[dict] = []
    for idx in top_3_indices:
        plant_name = _get_plant_name(int(idx), labels)
        conf       = float(preds[idx])
        predictions.append({
            "label":          plant_name,
            "plantName":      plant_name,
            "scientificName": plant_name,
            "class_index":    int(idx),
            "index":          int(idx),
            "confidence":     conf,
            "isDOHApproved":  False,
        })
        all_predictions.append({
            "class":       plant_name,
            "class_index": int(idx),
            "confidence":  conf,
        })

    # ---- Routing decision (mirrors backend/main.py CHANGELOG logic) --------
    toxic_names = {n.lower() for n in ood_config.get("toxic_blacklist", [])}
    top_name    = _get_plant_name(max_idx, labels)

    if top_name.lower() in toxic_names:
        routing = "toxic_warning"
    elif max_conf >= accept_threshold:
        routing = "accepted"
    elif max_conf >= ood_threshold:
        routing = "low_confidence"
    else:
        routing = "no_match"  # should not reach here after gate above

    logger.info(
        "Stage 2 PASS — top_class=%s, confidence=%.4f, routing=%s",
        top_name, max_conf, routing,
    )

    result_dict: dict = {
        "top_class":        top_name,
        "top_class_idx":    max_idx,
        "confidence":       max_conf,
        "predictions":      predictions,
        "all_predictions":  all_predictions,
        "img_array":        img_array,   # reused by Grad-CAM — do not copy
        "routing_decision": routing,
    }
    return True, result_dict


# ===========================================================================
# PIPELINE ENTRY POINT
# ===========================================================================

def run_pipeline(
    image_input: Union[bytes, str, Path],
    model=None,
    labels: dict | None = None,
) -> dict:
    """
    Two-stage image validation and inference pipeline.

    Accepts raw image bytes (API mode) or a filesystem path (standalone script
    mode).  When model and labels are not provided, loads them from disk
    (standalone mode only — in API mode they are passed from the FastAPI
    lifespan globals in main.py).

    Args:
        image_input: Raw image bytes, or a str / Path pointing to an image file.
        model:       Pre-loaded Keras model (or None → load from disk / TFLite).
        labels:      Label dict {"PlantName": class_index} (or None → load from disk).

    Returns:
        dict with keys:
            status (str):  "pass" | "fail"
            result:
              On "pass" → dict (see run_inference() docstring for full schema)
              On "fail" → str  (user-facing error message, e.g. _ERR_BLUR)

    Failure conditions (all return status="fail"):
        • image_input is a path that does not exist
        • image_input bytes cannot be decoded by OpenCV
        • Stage 1 blur or darkness check fails
        • Stage 2 OOD threshold not met
        • Model file missing (standalone / TFLite mode)
        • Any unhandled exception → logs and returns generic error
    """
    # ---- Resolve bytes -----------------------------------------------------
    try:
        if isinstance(image_input, (str, Path)):
            path = Path(image_input)
            if not path.exists():
                return {"status": "fail",
                        "result": f"Validation Failed: File not found: {path}"}
            image_bytes = path.read_bytes()
        elif isinstance(image_input, bytes):
            image_bytes = image_input
        else:
            return {"status": "fail",
                    "result": "Validation Failed: image_input must be bytes or a file path."}
    except OSError as exc:
        logger.error("run_pipeline: could not read image file: %s", exc)
        return {"status": "fail", "result": f"Validation Failed: {exc}"}

    # ---- Stage 1: Heuristic gatekeeper ------------------------------------
    passed, err = check_image_quality(image_bytes)
    if not passed:
        return {"status": "fail", "result": err}

    # ---- Load OOD config (cached) -----------------------------------------
    ood_config = load_ood_config()

    # ---- Load model / labels if not supplied (standalone mode) ------------
    _model  = model
    _labels = labels

    if _labels is None:
        if not LABELS_PATH.exists():
            return {"status": "fail",
                    "result": "Validation Failed: Labels file not found."}
        try:
            with LABELS_PATH.open("r", encoding="utf-8") as fh:
                _labels = json.load(fh)
        except Exception as exc:
            logger.error("run_pipeline: failed to load labels: %s", exc)
            return {"status": "fail",
                    "result": f"Validation Failed: Could not load labels: {exc}"}

    if _model is None and not USE_TFLITE:
        # Standalone Keras mode — load model from disk
        if not KERAS_MODEL_PATH.exists():
            return {"status": "fail",
                    "result": "Validation Failed: Model not available."}
        try:
            import tensorflow as tf
            logger.info("Standalone mode: loading Keras model from %s …", KERAS_MODEL_PATH)
            _model = tf.keras.models.load_model(str(KERAS_MODEL_PATH))
        except Exception as exc:
            logger.error("run_pipeline: failed to load Keras model: %s", exc)
            return {"status": "fail",
                    "result": f"Validation Failed: Could not load model: {exc}"}

    # ---- Stage 2: ML inference & OOD enforcement --------------------------
    try:
        passed, result = run_inference(image_bytes, _model, _labels, ood_config)
    except Exception as exc:
        logger.exception("run_pipeline: unexpected error in Stage 2.")
        return {"status": "fail",
                "result": f"Validation Failed: Inference error: {exc}"}

    if not passed:
        return {"status": "fail", "result": result}

    return {"status": "pass", "result": result}


# ===========================================================================
# STANDALONE SCRIPT MODE
# ===========================================================================

if __name__ == "__main__":
    """
    Run the two-stage pipeline on a single image file from the command line.

    Usage:
        python backend/utils/validation_pipeline.py /path/to/image.jpg

    Prints the pipeline result as pretty-printed JSON to stdout.
    Exit code: 0 on pass, 1 on fail.
    """
    import sys as _sys

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
    )

    if len(_sys.argv) < 2:
        print("Usage: python validation_pipeline.py <image_path>", file=_sys.stderr)
        _sys.exit(1)

    image_path = Path(_sys.argv[1])

    print(f"🔍 Running pipeline on: {image_path}", file=_sys.stderr)

    # Model and labels are None → run_pipeline loads them from disk
    pipeline_result = run_pipeline(image_path, model=None, labels=None)

    # Strip the numpy img_array from the output (not JSON-serialisable)
    if pipeline_result["status"] == "pass":
        output = dict(pipeline_result["result"])
        output.pop("img_array", None)
        pipeline_result = {"status": "pass", "result": output}

    print(json.dumps(pipeline_result, indent=2, ensure_ascii=False))
    _sys.exit(0 if pipeline_result["status"] == "pass" else 1)
