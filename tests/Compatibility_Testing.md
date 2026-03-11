# Compatibility Testing Plan — HerbaScan v0.9.3

**Testing Type:** Non-Functional — Compatibility  
**Scope:** Device OS versions, screen sizes, desktop/web platforms, iOS, and dark/light mode  
**Date:** March 7, 2026  
**Version:** v0.9.3

---

## Overview

Compatibility tests verify that HerbaScan functions correctly across the range of target environments: Android API levels 21–34, various screen sizes (small phone to tablet), Windows desktop (for admin use), and iOS. Dark/light mode compatibility is also validated. Tests use real devices where available and Android emulators/AVDs for lower API levels.

---

## Test Cases

| Test Case Scenario ID | Test Case Scenario | Action | Expected Result | Pass | Fail | Comments / Suggestions |
|---|---|---|---|---|---|---|
| CT-001 | Android API 21 (min supported) — full scan flow | Install the debug APK on an Android 5.0 (API 21) device or emulator; complete a full scan (camera capture + offline CAM); verify SQLite opens correctly; verify no `UnsatisfiedLinkError` for TFLite on ARMv7 | (1) Build APK with `flutter build apk --split-per-abi`; (2) Install `app-armeabi-v7a-debug.apk` on API 21 AVD or device; (3) Launch app; (4) Complete an offline scan | App installs and launches without crash; SQLite opens without `sqflite_common_ffi` (mobile path used); scan flow completes with TFLite; no `UnsatisfiedLinkError` logged | | | API 21 is minimum SDK (`minSdkVersion 21` in `build.gradle`). TFLite ARMv7 support confirmed with `tflite_flutter: ^0.11.0`. |
| CT-002 | Android API 34 (latest) — permissions model | Install APK on an Android 14 (API 34) device; verify that camera permission uses the new permission model; `READ_MEDIA_IMAGES` is requested instead of `READ_EXTERNAL_STORAGE`; gallery image selection works; notification permission is requested on first use | (1) Fresh install on API 34 device; (2) Grant camera permission when prompted; (3) Attempt gallery scan (image picker); (4) Trigger a preparation timer notification | All permissions granted via new API 34 model without crash; `READ_MEDIA_IMAGES` appears in permission dialog (not the deprecated `READ_EXTERNAL_STORAGE`); notification permission dialog appears; gallery and camera both function | | | `AndroidManifest.xml` must have `READ_MEDIA_IMAGES` for API 33+ and `READ_EXTERNAL_STORAGE maxSdkVersion="32"`. Verify in manifest. |
| CT-003 | Small screen — 5" 720p (ldpi/mdpi) | Run app on a small 5-inch 720×1280 screen device or emulator; navigate through all main screens; verify no horizontal overflow, no clipped buttons, and SegmentedButton (Device/Cloud) tabs are fully visible | Navigate: Home → Scan → Browse → History → Settings → Plant Detail → Preparation Guide; on History screen check Device/Cloud SegmentedButton | No `RenderFlex overflow` errors in console; all navigation buttons, tab labels, and card text are readable; no horizontal scrolling required on screens that should be fixed-width | | | If overflow occurs, document the screen and widget involved. The global text scale clamp (0.85–1.15) should prevent most overflow. |
| CT-004 | Large screen / tablet — 10" 1080p | Run app on a 10-inch 1920×1200 tablet; verify that Plant Detail 4-tab layout and Preparation Guide use the available width appropriately; verify Admin NavigationRail renders when width ≥ 800px | Navigate to Plant Detail, Preparation Guide, and Admin Portal on a 10" tablet (or emulator with tablet profile) | Plant Detail tabs and Preparation Guide content are not cramped; Admin portal shows `NavigationRail` sidebar (not Drawer) when `MediaQuery.size.width >= 800`; no extra whitespace or stretched cards | | | Admin NavigationRail threshold is 800px as defined in `admin_web_screen.dart`. |
| CT-005 | Windows desktop — admin portal (no camera, no TFLite) | Run `flutter run -d windows`; sign in with admin account; access Admin portal; verify SQLite via `sqflite_common_ffi` initializes; verify admin modules (Image Review, Plant Metadata, User Management) load; verify camera and TFLite are skipped gracefully | (1) `flutter run -d windows` from project root; (2) Sign in as admin; (3) Settings → Review submissions → Admin portal; (4) Navigate all three admin modules; (5) Observe any camera or TFLite references | App launches on Windows without `MissingPluginException` for camera or `dlopen` error for TFLite; SQLite initializes (`sqflite_common_ffi`); all three admin modules are accessible and functional; no crash | | | `CameraProvider` returns early with a friendly message on `Platform.isWindows`. `TflitePlantService.loadModel()` is a no-op on desktop. |
| CT-006 | iOS — deep link opens app from email client (if targeted) | On an iOS device (or simulator), trigger a Supabase auth deep link (`herbascan://auth/callback`); verify the link opens HerbaScan and the `AuthDeepLinkHandler` processes the session | (1) Tap a reset-password or signup-confirmation link from a mail client on iOS; (2) Observe whether the OS prompts to open HerbaScan; (3) After app opens, check if auth state updates | iOS system prompts to open HerbaScan for `herbascan://` URLs; app opens and `AuthDeepLinkHandler.getSessionFromUrl()` is called; user lands on Change Password screen (for reset) or is signed in (for confirmation) | | | Requires `CFBundleURLTypes` with scheme `herbascan` in `ios/Runner/Info.plist`. Test with both physical device and simulator. |
| CT-007 | Dark mode / light mode — all screens readable | Switch between dark and light mode; verify all screens render without white-on-white, black-on-black, or low-contrast text; specifically check SegmentedButton selected state (History), Approve button (Admin Image Review), and the "Active" user status chip (User Management) | (1) Enable dark mode (Android system); open all main screens; (2) Switch to light mode; repeat; specifically check History tabs, Admin Image Review Approve button, and User Management Active chip | In both modes: all button labels, tab labels, card text, and status chips are readable with sufficient contrast; no selected-state text blends with background | | | Known previously fixed items: History SegmentedButton, Approve button contrast, User Management "Active" chip. Regression check. |

---

## Notes

- For CT-001 and CT-002, use Android Studio AVD Manager to create API 21 and API 34 emulators if physical devices are not available.
- For CT-005, ensure `sqflite_common_ffi` is in `pubspec.yaml` and `initDatabaseFactory()` is called for desktop (`init_database_factory_ffi.dart`).
- iOS testing (CT-006) is only required if iOS deployment is planned; the app currently targets Android as primary platform.
- Screen sizes for CT-003 and CT-004 can be tested with Android emulators configured for those resolutions.
