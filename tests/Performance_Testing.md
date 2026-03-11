# Performance Testing Plan — HerbaScan v0.9.3

**Testing Type:** Non-Functional — Performance  
**Scope:** Timing, memory, responsiveness, and throughput under realistic and stress conditions  
**Date:** March 7, 2026  
**Version:** v0.9.3

---

## Overview

Performance tests measure HerbaScan against defined timing and resource budgets. Targets are set to ensure a satisfactory experience on mid-range Android devices (the primary target hardware for rural health workers) and to validate the Railway FastAPI backend's throughput. Tests use Flutter DevTools, Android Studio Profiler, and custom PerformanceMonitor logs.

---

## Test Cases

| Test Case Scenario ID | Test Case Scenario | Action | Expected Result | Pass | Fail | Comments / Suggestions |
|---|---|---|---|---|---|---|
| PT-001 | App cold start — splash to home screen fully loaded | Force-stop the app; relaunch from the device launcher; measure elapsed time from process start until the Home screen (`HomeScreen`) is fully rendered (plant count, Quick Actions, and Recent Scans visible) | Launch app on a mid-range Android device (API 26, 3 GB RAM, e.g. Infinix X6827); record time using `PerformanceMonitor.appStart` log line `⚡ app_start: Xms` from Flutter console | Cold start completes in **< 5 000 ms** (5 seconds); `app_start` log confirms timing | | | Repeat 5 times and record min/max/average. Warm restarts (not included in this test) should be < 2 s. |
| PT-002 | Online Grad-CAM latency — scan tap to heatmap visible | With Wi-Fi active and Railway instance warm, measure time from the scan button tap to `PlantResultScreen` fully rendered with heatmap image displayed | Tap scan; capture a leaf photo; start stopwatch at button tap; stop at heatmap visible in UI | Response time **< 8 000 ms** (8 seconds) on a 4G or Wi-Fi connection with a warm Railway instance | | | Record 5 trials. Cold Railway start (first request after idle) is excluded and documented separately (may be 10–30 s). If Railway is cold, warm it first with a `/health` call. |
| PT-003 | Offline TFLite inference time — capture to result displayed | With airplane mode active, measure time from image capture to `PlantResultScreen` fully loaded (plant name, CAM heatmap, confidence %) | Enable airplane mode; capture leaf photo; record elapsed time using `PerformanceMonitor` logs or manual stopwatch | Offline inference and screen render **< 3 000 ms** (3 seconds) | | | Run on same device (Infinix X6827). TFLite model is `mobilenetv2_multi_output.tflite` (~12 MB loaded in memory). |
| PT-004 | Catalog sync — Supabase to SQLite for 42 plants | Measure total time for `CatalogSyncService.syncFromSupabase()` to fetch all 42 plants plus related tables (medicinal uses, preparations, safety, habitat, conditions, anatomy) and write them to SQLite | Call `CatalogSyncService().syncFromSupabase()` from a fresh state (empty SQLite catalog tables); record start/end timestamps | Full sync completes in **< 10 000 ms** (10 seconds) on Wi-Fi; subsequent app launch serving from SQLite loads plants in **< 500 ms** | | | Log sync start and end in `CatalogSyncService`. Verify SQLite plant count equals 42 after sync. |
| PT-005 | Scan history load — 500 local scans in SQLite | Insert 500 synthetic `scan_history` rows into SQLite; open the History screen (Device tab); measure time to first item render and scroll performance | Seed SQLite with 500 rows; navigate to History → Device tab; record time from nav tap to first list item visible; scroll the list and measure frame rate | History list renders in **< 1 000 ms**; scroll maintains **60 fps** (no Choreographer "Skipped frames" > 16 ms logged) | | | Use `flutter_test` timer or Android Systrace for frame rate measurement. SQLite query uses indexed `scan_date` column so scan should be fast. |
| PT-006 | Concurrent Railway requests — load test | Send 50 simultaneous `POST /identify` requests to the Railway backend with real leaf image payloads and verify all respond successfully within the time budget without memory exhaustion | Use a Python/curl load-test script or `locust` to fire 50 parallel POST requests with a 300 KB JPEG payload each; monitor Railway dashboard for memory and response codes | All 50 requests return HTTP 200 within **30 seconds** total; no 503 errors; Railway memory stays **< 450 MB** | | | Run during off-peak hours. Railway free tier limits may throttle; document any throttling behavior. Memory measured via Railway dashboard metrics. |
| PT-007 | Memory leak — repeated PlantResultScreen opens | Open `PlantResultScreen` (with Grad-CAM heatmap) 20 consecutive times without navigating away to a different section of the app; measure Flutter heap growth | Automate with Flutter driver or manually open the same scan result 20 times; monitor Flutter DevTools → Memory → Heap snapshot before first and after 20th open | Heap growth **< 50 MB** total after 20 iterations; no unbounded growth pattern (monotonic increase every cycle indicates a leak) | | | Focus on heatmap `Uint8List` and image widget disposal. Use `ImageCache.clear()` check. Heap snapshots at iterations 1, 10, 20. |
| PT-008 | OfflineService initialization time | Measure the time from `OfflineService.initialize()` call to completion (all sub-services: `OfflineDataManager`, `OfflineSyncManager`, connectivity monitoring) visible in startup logs | Record `🔄 Initializing Offline Service...` and `✅ Offline Service initialized successfully` log timestamps on app launch | Offline service initialization completes in **< 2 000 ms** (2 seconds); does not block the main isolate perceptibly | | | Verify in Flutter DevTools timeline that the main thread is not blocked for more than 16 ms during initialization. |

---

## Notes

- All timing benchmarks are measured on the primary test device: **Infinix X6827, Android 13 (API 33), 4 GB RAM**.
- Performance targets are minimum acceptable; actual values should be recorded and compared against targets in the thesis performance analysis chapter.
- Use `PerformanceMonitor` service (already integrated in the app) to export timing JSON for thesis data.
- For PT-006, use a separate machine (not the test Android device) to generate load.
