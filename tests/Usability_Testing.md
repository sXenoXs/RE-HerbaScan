# Usability Testing Plan — HerbaScan v0.9.3

**Testing Type:** Non-Functional — Usability  
**Scope:** User experience, accessibility, discoverability, error recovery, and comprehension  
**Date:** March 7, 2026  
**Version:** v0.9.3

---

## Overview

Usability tests evaluate how easily real users — including non-technical community health workers, barangay health personnel, and students — can operate HerbaScan to accomplish their goals. Sessions are observed (think-aloud protocol) or measured via task-completion time and self-reported confidence scores (SUS or Likert scale). Results feed directly into the thesis usability assessment chapter.

---

## Test Cases

| Test Case Scenario ID | Test Case Scenario | Action | Expected Result | Pass | Fail | Comments / Suggestions |
|---|---|---|---|---|---|---|
| UT-USR-001 | New user first scan — no prior tutorial | A first-time user who has never seen HerbaScan (skip onboarding) opens the app, finds the scan feature, captures a plant, and reads the result — all without any assistance from the evaluator | Give the device to a new test participant with the instruction: "Find out what plant this is." (show a Lagundi sample). Observe and record time-to-first-result and participant's verbal confidence | Task completes (PlantResultScreen shown) in < 90 seconds without evaluator guidance; participant self-reports confidence ≥ 3/5 in understanding the result | | | Use think-aloud protocol. Note any points of confusion (e.g. camera icon not obvious, heatmap not understood). Record exact time from app open to reading the plant name. |
| UT-USR-002 | Poor-lighting error recovery flow | A user scanning in a dimly lit room encounters the "Poor Image Quality" screen; they use the provided tips and flashlight to retake a successful scan | Guide the participant to scan in a dim environment; after "Poor Image Quality" appears, observe whether they find and use the 6 tips to recover; measure whether a second attempt in better light succeeds | Participant finds "View Scanning Tips" without prompting; retries with flashlight; second scan succeeds (PlantResultScreen shown); total recovery < 2 minutes | | | Evaluate whether the 6 scanning tips are written clearly enough for a non-technical user. Rate tip clarity on 1–5 scale during debrief. |
| UT-USR-003 | Accessibility — system font scale at 200% | Set Android system font to maximum (200%); launch HerbaScan and navigate to Home, Browse, History, and PlantResultScreen; check that all critical text is readable and no overflow errors occur | Settings (Android) → Display → Font size → Largest; run HerbaScan; navigate to all main screens; look for any text clipped, overflowed, or obscured | No `RenderFlex overflow` errors in debug console; all screen labels and button text remain readable (not truncated beyond comprehension); text scale clamp (0.85–1.15) reduces maximum font growth | | | The global text scale clamp in `MaterialApp.router` `builder` limits scale to 1.15×. Verify its effect at 200% system scale. |
| UT-USR-004 | Contraindication warning clarity — toxic plant comprehension | A non-medical participant scans or is shown the result for Tuba-tuba; they read the Safety tab; they are then asked to explain back (without looking at the screen) what they understood about the plant's safety | Show participant the PlantResultScreen Safety tab for Tuba-tuba; after 1 minute of reading, ask "Is this plant safe? Can you eat it? What are the risks?" | Participant correctly identifies: (1) plant is NOT RECOMMENDED / toxic; (2) seeds are particularly dangerous; (3) should not be consumed or applied to skin; comprehension score ≥ 4/5 on evaluator rubric | | | Evaluator rates comprehension on a 5-point rubric. Low scores indicate the safety UI text needs clearer language or iconography. |
| UT-USR-005 | Preparation guide discoverability — within 3 taps | A user who has just seen the PlantResultScreen for Lagundi must find and start a preparation timer without evaluator guidance; measure number of taps required | From PlantResultScreen, observe the participant navigating: they must find Plant Detail → Medicinal tab → tap decoction → Preparation Guide → Start timer, all without prompting | Participant reaches the timer "Start" button in ≤ 5 taps from PlantResultScreen; no wrong turns that require backtracking more than once | | | If participant needs > 5 taps, document where they got lost. Compare Plant Detail navigation (bottom sheet vs direct navigation) for discoverability. |
| UT-USR-006 | Language switch mid-session — English to Filipino | A Filipino-speaking participant who initially used the app in English switches to Filipino in Settings; they verify that all text on the current screen and subsequent screens updates to Filipino immediately | Participant opens Settings → Language → Filipino; navigates back to Browse then opens a Plant Detail screen | All text updates to Filipino immediately (no app restart required); Navigation labels, tab names, error messages, and preparation guide steps all show Filipino text; participant confirms they can read and understand the content | | | Ask a native Filipino speaker to confirm translation quality for key medical terms (e.g. "contraindication" → "kontraindikasyon"). |
| UT-USR-007 | Account deactivation alert — user comprehension | An admin deactivates a test participant's account; the participant opens the app and sees the deactivation alert; they are asked what happened and what they should do | Admin deactivates test account; participant opens app; `AlertDialog` appears: "Your account has been deactivated by an administrator." | Alert is visible immediately on app open; participant understands they were deactivated (not that the app crashed); participant taps OK and lands on Login screen; they report they would contact an administrator | | | Assess whether "deactivated by an administrator" is clear enough. Suggest adding a support email or next-step instructions to the alert message. |
| UT-USR-008 | Browse and search — finding a plant by condition | A participant who needs to find plants for treating a cough uses Browse → By Condition → Cough and taps through to a plant detail; evaluate discoverability and time-on-task | Participant given task: "Find a plant that helps with cough and read how to prepare it."; observe navigation; record time | Participant finds Condition Search → selects "Cough" → taps a plant → reads Preparation Guide in < 3 minutes without assistance | | | Note if "By Condition" filter chip is discovered quickly or if the participant searches by name instead. Discoverability of the condition filter is a key UX metric. |

---

## Notes

- All usability sessions are conducted with informed consent (especially for thesis research data use).
- Minimum 5 participants for each test; target 10 participants for statistically meaningful results.
- Use a System Usability Scale (SUS) questionnaire after the session to compute an overall usability score (target SUS ≥ 70).
- Observations and audio recordings (with consent) should be transcribed and coded for thematic analysis in the thesis.
- Evaluator should NOT intervene or hint during tasks; note the exact moment any question is asked.
