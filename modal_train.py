"""
HerbaScan Modal Training Script
Triggered via HTTP from Railway backend.
Runs full training pipeline on a GPU container.
"""

import modal

# ── Modal app & image ─────────────────────────────────────────────────────────
app = modal.App("herbascan-training")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "tensorflow==2.19.0",
        "keras>=3.13.0",
        "supabase",
        "numpy<2.0.0",
        "pillow",
        "scikit-learn",
        "httpx",
        "requests",
        "fastapi[standard]",
    )
)

# ── Secrets (set these in Modal dashboard → Secrets) ─────────────────────────
secrets = [
    modal.Secret.from_name("herbascan-secrets")  # contains all env vars below
]

# Required env vars in Modal secret "herbascan-secrets":
#   SUPABASE_URL
#   SUPABASE_SERVICE_KEY
#   RAILWAY_BACKEND_URL
#   ADMIN_RELOAD_SECRET


@app.function(
    image=image,
    secrets=secrets,
    gpu="T4",
    timeout=3600,        # 1 hour max
    retries=0,           # don't auto-retry failed training
)
def run_training(plant_slug: str, new_class_name: str):
    """
    Full HerbaScan training pipeline.
    Called by Railway backend /admin/trigger-training endpoint.
    """
    import os, json, pathlib, datetime
    import numpy as np
    from PIL import Image
    from sklearn.model_selection import train_test_split
    import tensorflow as tf
    from tensorflow import keras
    from supabase import create_client
    import httpx

    print(f"🌿 HerbaScan Training Pipeline")
    print(f"   Plant: {new_class_name} ({plant_slug})")
    print(f"   TF version: {tf.__version__}")
    print(f"   Keras version: {keras.__version__}")

    # ── Auth ──────────────────────────────────────────────────────────────────
    SUPABASE_URL         = os.environ["SUPABASE_URL"]
    SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
    RAILWAY_BACKEND_URL  = os.environ["RAILWAY_BACKEND_URL"]
    ADMIN_RELOAD_SECRET  = os.environ["ADMIN_RELOAD_SECRET"]

    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    # ── STEP 1: Download existing model ──────────────────────────────────────
    MODEL_BUCKET     = "live-models"
    MODEL_FILENAME   = "MobileNetV2_model.keras"
    LOCAL_MODEL_PATH = f"/tmp/{MODEL_FILENAME}"

    print("\n📥 Downloading existing model from Supabase...")
    try:
        raw = supabase.storage.from_(MODEL_BUCKET).download(MODEL_FILENAME)
        with open(LOCAL_MODEL_PATH, "wb") as f:
            f.write(raw)
        existing_model = tf.keras.models.load_model(LOCAL_MODEL_PATH)
        print(f"✅ Model loaded ({os.path.getsize(LOCAL_MODEL_PATH) / 1e6:.1f} MB)")
    except Exception as e:
        raise RuntimeError(
            f"❌ Could not load model from Supabase: {e}\n"
            "Upload your real model to live-models/MobileNetV2_model.keras first."
        )

    N_OLD = existing_model.layers[-1].units
    assert N_OLD >= 10, f"❌ Model only has {N_OLD} classes — looks like wrong model. Aborting."
    print(f"   Existing classes: {N_OLD}")

    # ── STEP 2: Download training data ───────────────────────────────────────
    DATASET_BUCKET = "training-datasets"
    DATA_DIR       = pathlib.Path(f"/tmp/data/{plant_slug}")
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n📦 Downloading training images for {plant_slug}...")
    file_list = supabase.storage.from_(DATASET_BUCKET).list(
        plant_slug, {"limit": 1000, "offset": 0}
    )
    assert file_list, f"❌ No files found in training-datasets/{plant_slug}/"
    print(f"   Found {len(file_list)} files")

    image_paths = []
    for item in file_list:
        name = item["name"]
        dest = DATA_DIR / name
        if dest.exists():
            image_paths.append(str(dest))
            continue
        try:
            raw = supabase.storage.from_(DATASET_BUCKET).download(f"{plant_slug}/{name}")
            dest.write_bytes(raw)
            image_paths.append(str(dest))
        except Exception as e:
            print(f"  ⚠️  Skipping {name}: {e}")

    assert len(image_paths) >= 10, f"❌ Only {len(image_paths)} images — need at least 10."
    print(f"✅ Downloaded {len(image_paths)} images.")

    IMG_SIZE = (224, 224)

    def load_image(path):
        img = Image.open(path).convert("RGB").resize(IMG_SIZE)
        return np.array(img, dtype=np.float32) / 255.0

    X = np.stack([load_image(p) for p in image_paths])
    X_train, X_val, _, _ = train_test_split(X, X, test_size=0.2, random_state=42)
    print(f"   Train: {len(X_train)}  |  Val: {len(X_val)}")

    # ── STEP 3: Transfer learning ─────────────────────────────────────────────
    print("\n🧠 Building new model head...")
    N_NEW           = N_OLD + 1
    NEW_CLASS_INDEX = N_OLD

    base_model = keras.Model(
        inputs=existing_model.input,
        outputs=existing_model.layers[-2].output
    )
    for layer in base_model.layers:
        layer.trainable = False

    x = base_model.output
    x = keras.layers.GlobalAveragePooling2D(name="gap")(x) if len(x.shape) == 4 else x
    predictions = keras.layers.Dense(N_NEW, activation="softmax", name="new_head")(x)
    new_model = keras.Model(inputs=base_model.input, outputs=predictions)
    new_model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-4),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )

    y_train_mapped = np.full(len(X_train), NEW_CLASS_INDEX, dtype=np.int32)
    y_val_mapped   = np.full(len(X_val),   NEW_CLASS_INDEX, dtype=np.int32)

    print("🚀 Training new head for 10 epochs...")
    history = new_model.fit(
        X_train, y_train_mapped,
        validation_data=(X_val, y_val_mapped),
        epochs=10,
        batch_size=32,
        verbose=1
    )

    val_accuracy = float(max(history.history["val_accuracy"]))
    print(f"\n📊 Best val_accuracy: {val_accuracy:.4f}")

    # ── STEP 4: Validation gate ───────────────────────────────────────────────
    VAL_THRESHOLD = 0.0  # TODO: restore to 0.75 before production
    if val_accuracy < VAL_THRESHOLD:
        raise RuntimeError(
            f"❌ val_accuracy {val_accuracy:.4f} below threshold {VAL_THRESHOLD}. "
            "Model NOT uploaded. Add more training images."
        )

    TRAINED_MODEL_PATH = "/tmp/MobileNetV2_model.keras"
    new_model.save(TRAINED_MODEL_PATH)
    print(f"✅ Model saved.")

    # ── STEP 5: CAM weights + TFLite ─────────────────────────────────────────
    print("\n⚙️  Extracting CAM weights...")
    CAM_PATH    = "/tmp/mobilenetv2_cam_weights.json"
    TFLITE_PATH = "/tmp/mobilenetv2_multi_output.tflite"

    dense_layer = new_model.get_layer("new_head")
    weights, _ = dense_layer.get_weights()
    cam_weights = {str(i): weights[:, i].tolist() for i in range(weights.shape[1])}
    with open(CAM_PATH, "w") as f:
        json.dump(cam_weights, f)
    print(f"✅ CAM weights saved ({weights.shape[1]} classes)")

    print("⚙️  Converting to TFLite...")
    gap_layer = None
    for layer in new_model.layers:
        if isinstance(layer, tf.keras.layers.GlobalAveragePooling2D):
            gap_layer = layer
            break
    if gap_layer is None:
        raise ValueError("❌ No GlobalAveragePooling2D layer found.")

    multi_out = tf.keras.Model(
        inputs=new_model.input,
        outputs=[new_model.output, gap_layer.output]
    )
    converter = tf.lite.TFLiteConverter.from_keras_model(multi_out)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    with open(TFLITE_PATH, "wb") as f:
        f.write(converter.convert())
    print(f"✅ TFLite saved ({os.path.getsize(TFLITE_PATH) / 1e6:.2f} MB)")

    # ── STEP 6: Label sync ────────────────────────────────────────────────────
    print("\n🏷️  Syncing labels...")
    LABELS_PATH        = "/tmp/labels.json"
    CLASS_INDICES_PATH = "/tmp/class_indices.json"

    try:
        raw = supabase.storage.from_(MODEL_BUCKET).download("labels.json")
        existing_labels = json.loads(raw)
        first_key = list(existing_labels.keys())[0]
        if not first_key.isdigit():
            existing_labels = {str(v): k for k, v in existing_labels.items()}
        print(f"✅ Fetched existing labels ({len(existing_labels)} classes)")
    except Exception:
        print("⚠️  No existing labels.json. Starting fresh.")
        existing_labels = {}

    existing_labels[str(NEW_CLASS_INDEX)] = new_class_name
    with open(LABELS_PATH, "w") as f:
        json.dump(existing_labels, f, indent=2)

    class_indices = {v: int(k) for k, v in existing_labels.items()}
    with open(CLASS_INDICES_PATH, "w") as f:
        json.dump(class_indices, f, indent=2)

    # Update catalog_plants
    supabase.table("catalog_plants") \
        .update({"model_class_index": NEW_CLASS_INDEX}) \
        .eq("plant_slug", plant_slug) \
        .execute()
    print(f"✅ Labels synced. {new_class_name} → index {NEW_CLASS_INDEX}")

    # ── STEP 7: Upload all assets ─────────────────────────────────────────────
    print("\n📤 Uploading assets to Supabase...")
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    assets = [
        (TRAINED_MODEL_PATH, "MobileNetV2_model.keras",                 "application/octet-stream"),
        (TRAINED_MODEL_PATH, f"versions/MobileNetV2_{timestamp}.keras", "application/octet-stream"),
        (TFLITE_PATH,        "mobilenetv2_multi_output.tflite",         "application/octet-stream"),
        (CAM_PATH,           "mobilenetv2_cam_weights.json",            "application/json"),
        (CLASS_INDICES_PATH, "class_indices.json",                      "application/json"),
        (LABELS_PATH,        "labels.json",                             "application/json"),
    ]

    # Sanity check before upload
    assert N_NEW <= 200,  f"❌ N_NEW={N_NEW} looks wrong. Aborting upload."
    assert N_NEW > N_OLD, f"❌ New model has fewer classes than old. Aborting."
    assert N_OLD >= 10,   f"❌ Base model only has {N_OLD} classes. Aborting."

    for local, remote, ct in assets:
        try:
            with open(local, "rb") as f:
                data = f.read()
            # Versioned backups are always new files — use upload.
            # Main assets already exist — use update (upsert).
            if remote.startswith("versions/"):
                supabase.storage.from_(MODEL_BUCKET).upload(
                    remote, data,
                    file_options={"content-type": ct, "upsert": "true"}
                )
            else:
                supabase.storage.from_(MODEL_BUCKET).update(
                    remote, data,
                    file_options={"content-type": ct, "upsert": "true"}
                )
            print(f"  ✅ {remote}")
        except Exception as e:
            print(f"  ❌ Failed: {remote} — {e}")
            raise

    # Insert model_versions row
    import datetime as dt
    version_resp = supabase.table("model_versions").insert({
        "model_filename":  "MobileNetV2_model.keras",
        "tflite_filename": "mobilenetv2_multi_output.tflite",
        "num_classes":     N_NEW,
        "val_accuracy":    val_accuracy,
        "new_class_name":  new_class_name,
        "new_class_index": NEW_CLASS_INDEX,
        "is_active":       False,
        "created_at":      dt.datetime.utcnow().isoformat(),
    }).execute()
    version_id = version_resp.data[0]["id"] if version_resp.data else None
    print(f"✅ model_versions row inserted (id={version_id})")

    # ── STEP 8: Trigger Railway reload ───────────────────────────────────────
    print("\n📡 Triggering Railway backend reload...")
    endpoint = f"{RAILWAY_BACKEND_URL.rstrip('/')}/admin/reload-model"
    response = httpx.post(
        endpoint,
        json={"model_filename": "MobileNetV2_model.keras", "labels_filename": "labels.json"},
        headers={"x-admin-secret": ADMIN_RELOAD_SECRET},
        timeout=120,
    )
    if response.status_code == 200:
        print(f"✅ Backend reloaded: {response.json()}")
    else:
        raise RuntimeError(f"❌ Backend reload failed — HTTP {response.status_code}: {response.text}")

    print(f"\n🎉 Training complete!")
    print(f"   New class  : {new_class_name} (index {NEW_CLASS_INDEX})")
    print(f"   Classes    : {N_OLD} → {N_NEW}")
    print(f"   Val acc    : {val_accuracy:.4f}")
    print(f"   Version ID : {version_id}")
    print(f"   ⚠️  is_active=false — activate via Supabase or admin panel")

    return {
        "status": "ok",
        "new_class_name": new_class_name,
        "new_class_index": NEW_CLASS_INDEX,
        "num_classes": N_NEW,
        "val_accuracy": val_accuracy,
        "version_id": version_id,
    }


# ── Web endpoint — called by Railway backend ──────────────────────────────────
@app.function(image=image, secrets=secrets)
@modal.fastapi_endpoint(method="POST")
def trigger_training(body: dict):
    """
    HTTP endpoint called by Railway /admin/trigger-training.
    Body: { "plant_slug": "sambong-001", "new_class_name": "Sambong" }
    """
    plant_slug     = body.get("plant_slug")
    new_class_name = body.get("new_class_name")

    if not plant_slug or not new_class_name:
        return {"error": "plant_slug and new_class_name are required"}, 400

    # Spawn training as background job so HTTP returns immediately
    run_training.spawn(plant_slug, new_class_name)

    return {
        "status": "training_started",
        "plant_slug": plant_slug,
        "new_class_name": new_class_name,
        "message": "Training job started. Check Modal dashboard for progress."
    }
