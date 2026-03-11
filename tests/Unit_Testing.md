# Unit Testing Plan — HerbaScan v0.9.3

**Testing Type:** Functional — Unit  
**Scope:** Individual Dart functions/methods in isolation with mocked dependencies  
**Date:** March 7, 2026  
**Version:** v0.9.3

---

## Overview

Unit tests verify that each service method, provider method, or utility function produces the correct output for a given input, independent of external systems (Supabase, Railway, SQLite, file system). Dependencies are mocked or stubbed where needed.

---

## Test Cases

| Test Case Scenario ID | Name of the Module / Function | Test Case Scenario | Action | Actual Input | Pass | Fail | Comments / Suggestions |
|---|---|---|---|---|---|---|---|
| UT-001 | `XAIExplanationService.getExplanation()` — known plant key | Verify that a known plant key returns a well-formed `PlantExplanation` with all four required sections (taxonomy, ecology, medicinal_preparation, safety_consideration) populated and non-empty | Call `XAIExplanationService().getExplanation(plantName: "Lagundi", scientificName: "Vitex negundo", confidence: 0.95)` against the bundled `plant_explanations.json` asset (no live LLM) | `plantName = "Lagundi"`, `scientificName = "Vitex negundo"`, `confidence = 0.95` | | | Expects JSON lookup to succeed on priority 2 (asset JSON). Source badge must resolve to "Offline". |
| UT-002 | `XAIExplanationService.getExplanation()` — unknown plant key | Verify that an unrecognised plant name falls through all priorities (cache → JSON → fallback) and returns a non-null `PlantExplanation` with non-empty fallback text instead of throwing an exception | Call `getExplanation(plantName: "UnknownPlant999", scientificName: null, confidence: 0.0)` | `plantName = "UnknownPlant999"`, `scientificName = null`, `confidence = 0.0` | | | Must not crash. Fallback text should contain a user-friendly "No explanation available" message. |
| UT-003 | `SafetyProfileService.getSafetyProfile()` — SQLite hit | Verify that when a row for a given plant exists in the local `safety_profiles` SQLite table, the service returns that row and does NOT read `safety_profiles.json` | Seed a mock SQLite DB with one Adelfa row; call `getSafetyProfile(plant)` with a mocked `DatabaseService` returning that row | `plantId = "adelfa-001"`, mock SQLite row: `is_generally_safe = false`, `strict_contraindications = ["Cardiac glycosides"]` | | | Asset JSON fallback path must be bypassed. Verify by asserting the JSON asset loader is never called. |
| UT-004 | `SafetyProfileService.getSafetyProfile()` — asset JSON fallback | Verify that when SQLite returns null (no row for plant), the service correctly parses the bundled `safety_profiles.json` and returns a valid `SafetyProfile` with `strict_contraindications` populated for Adelfa | Mock `DatabaseService.getSafetyProfile()` to return `null`; call service with `plantId = "adelfa-001"` | `plantId = "adelfa-001"`, SQLite returns `null` | | | Adelfa entry in JSON must have `strict_contraindications` non-empty (cardiac glycosides / oleander toxins). |
| UT-005 | `PreparationStepParser.parseTimerSecondsFromInstruction()` — range minutes | Verify that a time range phrase "10-15 minutes" is parsed to 900 seconds (upper bound, i.e. 15 × 60) | Call `parseTimerSecondsFromInstruction("Simmer the leaves for 10-15 minutes until the water reduces.")` | Input string containing "10-15 minutes" | | | Parser must use the upper bound of a range. Result must be `== 900`. |
| UT-006 | `PreparationStepParser.parseTimerSecondsFromInstruction()` — seconds | Verify that "30 seconds" parses to 30 (not 1800) | Call `parseTimerSecondsFromInstruction("Steep for 30 seconds then remove from heat.")` | Input string containing "30 seconds" | | | Must correctly distinguish "seconds" unit from "minutes". Result must be `== 30`. |
| UT-007 | `PlantDataService._getAllMedicinalPlantsData()` — count and uniqueness | Verify that the in-memory plant data set contains exactly 42 plants, that every plant has a unique `id`, and that every plant has at least one entry in `medicinalUses` | Call `PlantDataService().getAllMedicinalPlantsData()` and inspect the returned list | No external input; method reads from hardcoded data | | | Count must be exactly 42. Duplicate IDs must be zero. Plants with empty `medicinalUses` list must be zero. |
| UT-008 | `DatabaseService.insertScanHistory()` — duplicate ID replace | Verify that inserting a `ScanResult` with an ID that already exists in the `scan_history` table does not throw a `DatabaseException` (UNIQUE constraint) and that the existing row is updated via `ConflictAlgorithm.replace` | Insert a scan with `id = "test-scan-001"` twice; the second insert changes `confidence = 0.99` | First: `id="test-scan-001"`, `confidence=0.80`; Second: same `id`, `confidence=0.99` | | | After the second insert, query should return the row with `confidence = 0.99`. No exception thrown. |
| UT-009 | `OnlineGradCAMService._parseLabelFormat()` — numeric prefix strip | Verify that the label parser correctly strips numeric prefixes and parenthetical model codes from backend label strings, returning a clean, human-readable plant name | Call the internal label parser (or the public method that uses it) with `"4Vitex negundo(VN)"` | Input: `"4Vitex negundo(VN)"` | | | Expected output: a string mapped to `"Lagundi"` via `class_indices.json` reverse lookup, or at minimum `"Vitex negundo"` with prefix and code stripped. Must not contain leading digits or parenthetical codes. |
| UT-010 | `AuthProvider._loadRole()` — deactivated account | Verify that when `profiles` returns `is_active: false` for the current user, `_loadRole()` sets `wasDeactivatedByAdmin = true` and calls `signOut()`, leaving `isLoggedIn` as `false` | Mock `AuthService` to return a session; mock Supabase `profiles` query to return `{ role: "user", is_active: false }`; construct `AuthProvider` and await the role load | Mock profile row: `{ role: "user", is_active: false }` | | | `wasDeactivatedByAdmin` must be `true`. `isLoggedIn` must be `false`. `signOut()` must have been called exactly once. |
| UT-011 | `PreparationNotificationService.scheduleTimer()` — schedule and cancel | Verify that `scheduleTimer(id, remainingSeconds)` schedules exactly one local notification with the correct remaining time, and that `cancelTimer(id)` removes it | Call `scheduleTimer("prep-step-1", 900)` then `cancelTimer("prep-step-1")`; inspect `flutter_local_notifications` mock | `id = "prep-step-1"`, `remainingSeconds = 900` (15 minutes) | | | After `scheduleTimer`, pending notification count for the id must be 1. After `cancelTimer`, pending count must be 0. |
| UT-012 | `PlantProvider.getPlantAnatomy()` — missing table graceful return | Verify that when `catalog_plant_anatomy` table does not exist in SQLite (e.g. fresh install before sync), `getPlantAnatomy()` returns an empty list and does not crash or throw an unhandled exception | Mock `DatabaseService.getAnatomyForPlant()` to throw `DatabaseException`; call `PlantProvider.getPlantAnatomy("lagundi-001")` | `plantId = "lagundi-001"`, DB throws `DatabaseException` | | | Must return `[]` (empty list). No exception must propagate to the UI layer. |

---

## Notes

- All unit tests use mock/stub implementations of `DatabaseService`, `Supabase`, and file assets where needed.
- Run with: `flutter test test/unit/`
- Coverage target: ≥ 80% line coverage for all service classes listed above.
