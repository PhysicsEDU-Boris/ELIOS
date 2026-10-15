# Handoff

- Branch: `feat/m2c-crop-identify` (continues the M2b prefetch handoff).
- Latest commit: see `git log -1`.

## Done — M2c

- LIVE_SCAN locks now pass the full detection and its same stream frame to
  the quiz provider. Crop runs off the UI isolate via `compute`; center
  coordinates scale to decoded image size and clamp to image edges.
- Gemma identifies only the crop, then questions use its item/material.
  Popup shows “Looking…” during identification. Live preload includes
  vision. Invalid crops or unknown images stop without a label-only quiz.
- B3 from either detector or Gemma is preserved. Hazard confirmation offers
  “Lanjut kuis” / “Scan ulang” before any question generation, including
  photo and label-only sessions. Dismissed/late results cannot reopen it.
- All 10 firmware classes mapped explicitly; Human_Hand remains ignored.
- Decision [0012](decisions/0012-crop-identification-and-hazards.md) and
  CHANGELOG updated. Existing user Xcode scheme and Maixcam.txt excluded.

## Tests

- `flutter analyze --no-pub`: clean.
- Full `flutter test --no-pub`: 219 passed; only the 2 documented stale
  splash tests in test/widget_test.dart failed.
- Five behavior break-checks failed as expected, then fixes restored:
  full-frame instead of crop; keyword-only mapping; immediate quiz without
  hazard confirmation; old identifying text; old JSON string cast.
- Focused tests after restoration: 89/89 passed.
- `bash scripts/check-secrets.sh`: clean.

## Robot test needed

Build `flutter build macos --debug --dart-define=LIVE_SCAN=true`, then
`open build/macos/Build/Products/Debug/*.app` (not IDE flutter run).

1. Hold a plastic bottle/cardboard still: “Looking…” then a quiz naming the
   actual item. Hold 60 s: only one identification. Preview stays live.
2. Show e-waste/battery: B3 warning before any question. “Lanjut kuis” starts
   it; repeat later with “Scan ulang” and verify no quiz opens afterward.
3. Close during “Looking…”; the late result must not reopen the popup.
4. Try an edge-of-frame item, unclear image, Paperboard and Tetra_Pak.
   Unknown images should request a rescan; a hand alone never triggers.
5. Check existing cooldown/empty-scene re-arm and same-label suppression.

Not validated on robot hardware. Watch image-encoder memory/latency and
recognition quality; firmware currently burns overlays into the JPEG.
