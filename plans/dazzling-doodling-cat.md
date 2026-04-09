# Plan: Full OOD Safety Config — Offline (Flutter/Dart) + Online (Python) Parity

## Context

The backend Python pipeline (`validation_pipeline.py`) now has a strict two-stage gate (blur/darkness → OOD confidence), but the Flutter offline path has **none of this**. The `assets/data/ood_safety_config.json` file exists in the app bundle but zero Dart code reads it. Additionally, when the backend returns HTTP 422 (validation failure), Flutter treats it identically to a 500 error — silently returns `null` and falls back to offline inference, which defeats the purpose of Stage 1 rejection entirely.

### What "⚠️ Partial" and "❌ Not implemented" meant:

- `assets/data/ood_safety_config.json` — exists but **never parsed by any Dart code**
- Blur/darkness checks — **completely absent** from the Flutter offline pipeline
- OOD confidence threshold — only a hardcoded 0.1 minimum in `TflitePlantService` (useless for OOD)
- HTTP 422 handling — treated same as 500; always falls back to offline (wrong)
- `PoorImageQualityScreen` — exists but **never called from anywhere in the codebase**

---

## Files to Create

| File | Purpose |
| ---- | ------- |
| `lib/core/services/ood_config_service.dart` | Load + cache `assets/data/ood_safety_config.json`; expose typed fields to all services |
| `lib/core/services/image_quality_service.dart` | Stage 1 Dart equivalent — blur (Variance of Laplacian) + darkness checks on raw image bytes |

## Files to Modify

| File | Change |
| ---- | ------ |
| `lib/core/services/online_gradcam_service.dart` | Distinguish HTTP 422 (validation failure) from 5xx (server error); return structured error map instead of `null` |
| `lib/core/services/adaptive_gradcam_service.dart` | Run Stage 1 **before** online or offline; don't fall back to offline on 422; route Stage 2 OOD failures correctly |
| `lib/core/services/offline_cam_service_io.dart` | Stage 2 OOD enforcement using `OodConfigService` after inference |
| `lib/features/scan/scan_screen.dart` | Route Stage 1 failures → `PoorImageQualityScreen`; Stage 2 OOD → `NoMatchFoundScreen` with low confidence |

---

## 1. `OodConfigService` (new)

Singleton that loads `assets/data/ood_safety_config.json` once at first use.

```dart
class OodConfigService {
  // Cached fields after load
  double blurThreshold;          // = 100.0 (raw Var of Laplacian)
  double darknessThreshold;      // = 40.0  (raw [0-255] grayscale mean)
  double confidenceThresholdOod; // = 0.4
  double confidenceThresholdAccept; // = 0.6
  int notPlantClassIndex;        // = -1 (disabled if < 0 or >= num_classes)
  List<String> toxicBlacklist;   // ["Adelfa", "IpilIpil", "TubaTuba"]

  Future<void> load();           // reads rootBundle, sets fields; safe to call multiple times
}
```

Config key mapping:
- `ood_blur_threshold` → `blurThreshold`
- `ood_darkness_threshold` → `darknessThreshold`
- `confidence_threshold_ood` → `confidenceThresholdOod`
- `confidence_threshold_accept` → `confidenceThresholdAccept`
- `not_plant_class_index` → `notPlantClassIndex`
- `toxic_blacklist` → `toxicBlacklist`

Uses `rootBundle.loadString('assets/data/ood_safety_config.json')`. Hard-coded defaults if file missing or malformed (same as Python pipeline defaults).

---

## 2. `ImageQualityService` (new) — Stage 1 Dart

Uses the **`image`** package (already a dependency, used in `offline_cam_service_io.dart`).

```dart
class ImageQualityResult {
  final bool passed;
  final String? failureReason; // null if passed; one of the error strings if failed
}

class ImageQualityService {
  final OodConfigService _oodConfig;

  Future<ImageQualityResult> check(Uint8List imageBytes);
}
```

**Blur check (Variance of Laplacian equivalent):**

```dart
// Decode → grayscale → apply discrete Laplacian kernel → compute variance
// Laplacian 3×3 kernel: centre = -4, cardinal neighbours = +1
// lap_var = variance of all kernel responses across the image
// Reject if lap_var < _oodConfig.blurThreshold (default 100.0)
```

**Darkness check:**

```dart
// Decode → grayscale → compute mean pixel value [0-255]
// Reject if mean < _oodConfig.darknessThreshold (default 40.0)
```

Error strings (must exactly match Python backend to keep Flutter routing consistent):
- `"Validation Failed: Image is too blurry."`
- `"Validation Failed: Image is too dark."`

Returns `ImageQualityResult(passed: false, failureReason: "...")` on first failure; `ImageQualityResult(passed: true)` if both pass.

---

## 3. `online_gradcam_service.dart` — 422 Handling

**Current behaviour:** any non-200 status → `_logger.e(...)` → `return null`

**New behaviour:**
```dart
if (response.statusCode == 200) {
  // ... existing success path unchanged ...
  return data;
} else if (response.statusCode == 422) {
  // Validation failure from backend Stage 1 or Stage 2
  // Parse JSON body: {"detail": "Validation Failed: Image is too blurry."}
  String detail = 'Validation Failed: Subject unrecognized or not a plant.';
  try {
    final body = jsonDecode(response.body);
    detail = body['detail'] as String? ?? detail;
  } catch (_) {}
  return {
    'validation_failed': true,
    'failure_reason': detail,
  };
} else {
  // 5xx or other server error — return null (triggers offline fallback)
  _logger.e('Server error: ${response.statusCode} - ${response.body}');
  return null;
}
```

The key distinction: `validation_failed: true` signals to the caller that this is a hard rejection, not a service failure — **no fallback to offline**.

---

## 4. `adaptive_gradcam_service.dart` — Stage 1 Gate + Routing

Add `ImageQualityService` and `OodConfigService` as dependencies.

**New flow in `identifyPlant()`:**

```text
Step 0 (NEW): Stage 1 — ImageQualityService.check(imageBytes)
   → failed  → return {'validation_failed': true, 'failure_reason': '...', 'stage': 1}
   → passed  → continue

Step 1: Check connectivity
   → online available → _tryOnline(imagePath)
        → result has 'validation_failed: true' → return as-is (NO offline fallback)
        → result is null (5xx / network) → fall through to offline
        → result is valid → return {result, 'fallback_used': false}

   → offline → _tryOffline(imageBytes)
        → result has 'validation_failed: true' (Stage 2 OOD) → return as-is
        → result is null (model error) → return existing error structure
        → result is valid → return {result, 'fallback_used': true}
```

The `stage` key in the error response tells `scan_screen.dart` which screen to route to:
- `stage: 1` → `PoorImageQualityScreen`
- `stage: 2` → `NoMatchFoundScreen` (with low-confidence badge)

---

## 5. `offline_cam_service_io.dart` — Stage 2 OOD (offline)

After `_runInference()` returns `predictions`:

```dart
// Load OOD config (singleton, already loaded by this point)
final oodConfig = OodConfigService();
final maxConf = predictions.reduce(max);  // max confidence value
final maxIdx  = predictions.indexOf(maxConf);

// Optional not_plant check
if (oodConfig.notPlantClassIndex >= 0 &&
    oodConfig.notPlantClassIndex < predictions.length &&
    maxIdx == oodConfig.notPlantClassIndex) {
  return {
    'validation_failed': true,
    'failure_reason': 'Validation Failed: Subject unrecognized or not a plant.',
    'stage': 2,
  };
}

// OOD threshold gate
if (maxConf < oodConfig.confidenceThresholdOod) {
  return {
    'validation_failed': true,
    'failure_reason': 'Validation Failed: Subject unrecognized or not a plant.',
    'stage': 2,
  };
}
// ... continue to CAM generation ...
```

---

## 6. `scan_screen.dart` — Error Routing

Replace the current `predictions.isEmpty → SnackBar` path with structured routing:

```dart
final result = await cameraProvider.processPlantIdentificationWithGradCAM(imageBytes);

// --- NEW: Check for validation failures before reading predictions ---
if (result['validation_failed'] == true) {
  final reason = result['failure_reason'] as String? ?? '';
  final stage  = result['stage'] as int? ?? 2;

  if (stage == 1) {
    // Stage 1: blur or darkness → PoorImageQualityScreen
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PoorImageQualityScreen(imagePath: image.path),
    ));
  } else {
    // Stage 2: OOD — Subject unrecognized
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoMatchFoundScreen(
        imagePath: image.path,
        lowConfidence: 0.0,  // triggers confidence badge
      ),
    ));
  }
  return;
}

// --- Existing routing (unchanged) ---
final predictions = result['predictions'] as List<Map<String,dynamic>>? ?? [];
if (predictions.isNotEmpty) {
  if (isTopPredictionBlacklisted(predictions)) { ... }
  else { → PlantResultScreen }
} else {
  SnackBar('No plant detected.');
}
```

This also applies identically to `_pickFromGallery()`.

---

## Dart Blur Computation Detail

Dart doesn't have OpenCV. Using the `image` package:

```dart
import 'package:image/image.dart' as img;

double _computeBlurScore(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return 0.0;
  final gray = img.grayscale(image);

  // Discrete Laplacian: centre pixel * -4, four cardinal neighbours * +1
  // Collect all response values, then compute variance
  final List<double> responses = [];
  final w = gray.width, h = gray.height;
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final c  = img.getLuminance(gray.getPixel(x,   y));
      final n  = img.getLuminance(gray.getPixel(x,   y-1));
      final s  = img.getLuminance(gray.getPixel(x,   y+1));
      final e  = img.getLuminance(gray.getPixel(x+1, y));
      final ww = img.getLuminance(gray.getPixel(x-1, y));
      responses.add((n + s + e + ww - 4 * c).toDouble());
    }
  }
  if (responses.isEmpty) return 0.0;
  final mean = responses.reduce((a,b) => a+b) / responses.length;
  final variance = responses.map((v) => (v - mean)*(v - mean))
                            .reduce((a,b) => a+b) / responses.length;
  return variance;
}
```

---

## Flow Diagram (After Implementation)

```text
User takes photo
      │
      ▼
AdaptiveGradCAMService.identifyPlant()
      │
      ├── Stage 1: ImageQualityService.check(imageBytes)
      │       ├── blur < 100  → {validation_failed, stage:1, reason: "too blurry"}
      │       └── dark < 40   → {validation_failed, stage:1, reason: "too dark"}
      │
      ├── [if online] OnlineGradCAMService.identifyPlant()
      │       ├── 200         → success result
      │       ├── 422         → {validation_failed, stage:1|2, reason: detail}
      │       └── 5xx/timeout → null → fallback to offline
      │
      └── [if offline / fallback] OfflineCAMService.identifyPlantWithCAM()
              ├── Stage 2 OOD gate (new, using OodConfigService)
              │     ├── conf < 0.4 → {validation_failed, stage:2, reason: "unrecognized"}
              │     └── not_plant  → {validation_failed, stage:2, reason: "unrecognized"}
              └── passed → CAM heatmap + predictions

scan_screen.dart
      ├── validation_failed + stage:1 → PoorImageQualityScreen
      ├── validation_failed + stage:2 → NoMatchFoundScreen (OOD badge)
      ├── toxic blacklist             → NoMatchFoundScreen (toxic warning)
      └── predictions present         → PlantResultScreen
```

---

## Verification

1. **Blurry image (offline):** Near-solid-colour image → `ImageQualityService` returns blur < 100 → `PoorImageQualityScreen` shown; offline model never called.
2. **Dark image (offline):** Nearly black image → mean < 40 → `PoorImageQualityScreen` shown.
3. **OOD image (offline):** Sharp well-lit shoe photo → Stage 1 passes → offline inference → max confidence 0.3 < 0.4 → `NoMatchFoundScreen`.
4. **OOD image (online):** Same shoe → backend returns HTTP 422 → Flutter does NOT fall back to offline → `NoMatchFoundScreen`.
5. **Valid plant (offline):** Good leaf photo → Stage 1 passes → offline inference → confidence 0.85 ≥ 0.4 → `PlantResultScreen`.
6. **Valid plant (online):** Good leaf photo → backend returns 200 → `PlantResultScreen`.
7. **Config missing:** Delete `assets/data/ood_safety_config.json` → `OodConfigService` uses hard-coded defaults → app still works.
8. **`PoorImageQualityScreen` actually shown:** Currently unreachable — this plan makes it reachable for the first time.
