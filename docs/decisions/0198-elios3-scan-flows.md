# 0198 — ELIOS 3 scan flows: phone Scan & quiz, Scan to contribute, ELIOS setup quiz card

Date: 10 November 2026

Third PR of the ELIOS 3 series, stacked on `feat/elios3-home-learn` (0197). Figma
J2jSbARJSyJCStNFeWkWDj: Scan & quiz 629:90736–90816, ELIOS setup 629:90894, contribute
629:91042 / 629:91074. Owner choices (10 Nov): contribute = app-only check; robot quiz off =
save the scan without a quiz.

- **Scan & quiz (phone), portrait**: new `PhoneScanScreen` — full-screen camera, square
  viewfinder corners, "Hold steady" hint, shutter, chip showing the Profile question source. The
  photo is cropped to the viewfinder (`cropToViewfinder`; `decodeJpg` already applies the EXIF
  rotation, guarded by a test) and goes through the existing `onPhotoCaptured` → identify → quiz.
  The quiz is the existing popup; its loading skeleton now fits a portrait phone and answer tiles
  show up to 6 lines when tall. The Figma "identified → Start quiz" card is not a separate step.
  The old landscape `DeviceScanScreen` stays (History's "start scan" route still uses it).
- **Scan to contribute** (`ContributeScreen`): pick the bin (Organik / Anorganik / B3), record
  up to 9 s (a photo every 3 s, Stop early allowed), each photo → existing ELIOS AI identify; the
  most common bin wins (`pickContribution`). If it matches the chosen bin (residu counts as
  Anorganik, `contributionMatches`), a History record with `kind: 'contribution'`, no questions
  and 10 trophies is saved (cloud sync stores the JSON as is; old records have no `kind`). A
  mismatch or no item saves nothing. No backend change. A video is not uploaded or kept.
- **ELIOS setup**: subtitle and "Change" (back to Select vehicle) in the header; camera row
  "Camera: MaixCAM2 · Automatic"; connected state offers **Open control** (was a disabled
  "Connected"); auto-reconnect is in the connection card and Resolution / Show FPS in a
  "Video stream" card, so the C1 settings sheet is gone (`ConfigSegmented` kept). Quiz card:
  **Quiz after each scan** (on/off) + Question bank | ELIOS AI for robot scans only.
- **Prefs**: `robotQuizEnabled` (default on) and `robotQuestionSource` (defaults to the saved
  shared `questionSource`, so nothing changes for existing users). Robot sessions (`onRobotLocked`,
  `scanLocked`) read the robot source; phone sessions read Profile's. With the robot quiz off, the
  identified item is saved to History (bin, photo, 0 trophies) and the popup shows "Saved to
  History. The quiz is off for robot scans."

Not done: the Figma ELIOS setup hero with floating Status/Battery/Camera bubbles and the
connection stepper (the existing hero and connection card are kept, restyled lightly); History
shows a contribution like a scan with 0 questions (PR 4 adds a contribution label); flash and
gallery buttons on the camera.
