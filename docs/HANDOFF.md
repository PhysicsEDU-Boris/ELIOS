# Handoff

- Branch `feat/m2c-crop-identify`; prior commits preserved; no push/merge.
- Clean path local only, NOT deployed; M2c NOT complete.

## Verified hardware evidence (before this fix)

- Exact model inputs contain red masks/green box edges, copied under ignored
  `m2c-diagnostics/` in this repo. Each ID has `-identify.jpg` and `.jsonl`:
  `scan-1792088943399297-0` (01:29:03 WIB): ponsel/anorganik;
  `scan-1792088975920656-1` (01:29:35): limbah cair/residu;
  `scan-1792089028005351-2` (01:30:28): perangkat elektronik/scanner/anorganik.
- All three E_Waste locks correctly resolved hazardous. Third Continue opened
  quiz. Contamination proven; effect on accuracy not established.
- These follow the rebuilt b1c6d46 app launch at 01:13:18 WIB, 16 Oct 2026;
  keep distinct from old `scan-1792085518243375-0` at 00:31:58.
- Third timing: crop 41 ms; identify first token 5.056 s / complete 5.844 s;
  confirmation wait 10.369 s; question generation 5.562 s / first token 728 ms;
  total lock-to-question 21.820 s includes human wait, not just generation.

## Implemented / compatibility

- Deployable `firmware/maixcam2/main.py` encodes originals BEFORE annotations.
  Same-message clean_image/clean_detections carry matching frame IDs and hash.
  Only fresh matched inference boxes qualify; cached/held boxes remain preview.
- One additional JPEG per nonempty inference frame, none on intervening/empty
  or held-only frames. Existing annotated preview is retained on every frame.
- Flutter retains separate preview/clean bytes; rejects missing/mismatched clean
  data, never falls back to annotated pixels. Preview-only is not empty-scene.
- Legacy firmware: preview/controls and label-only mode work; LIVE_SCAN needs
  firmware update, otherwise a notice replaces identification. Old apps ignore
  added fields and still identify annotated images. Extra bandwidth/FPS untested.
- Hazard veto, cancellation, model slot and anti-spam thresholds unchanged.
  Lock sampling now follows fresh inference cadence; hardware retest required.

## Diagnostics / deployment

- Actual original diagnostic directory (macOS may require Finder copy):
  `/Users/macbookairm12020/Library/Containers/E798601C-A67E-46BF-AB3D-AE1A58572F44/Data/Library/Application Support/com.boris.elio/m2c-diagnostics/`
- New JSONL logs imageSource, frameId/detectionFrameId and firmwareSha256.
  Artifacts remain local/gitignored. No keys, test images or Maixcam.txt committed.
- Follow `firmware/maixcam2/README.md`: back up/compare active robot source,
  deploy main.py to its confirmed entry point, verify startup/hash against
  `shasum -a 256 firmware/maixcam2/main.py`. Deployment NOT verified here.
- Build `flutter build macos --debug --dart-define=LIVE_SCAN=true`; quit old
  app, then `open build/macos/Build/Products/Debug/ELIOS.app` (not flutter run).

## Checks / remaining gates

- Analyzer clean. Full tests: 226 pass; only 2 known stale splash failures.
  Firmware stream test passes; annotated-selection and post-drawing-encoding
  break-checks both fail as intended, fixes restored. Secret scan clean.
- Owner: exact saved JPEG has NO synthetic annotation; IDs/hash match; preview
  still segments and visibly moves during identify, confirmation and quiz.
  Test isolated phone/bottle recognition and E_Waste veto on Gemma disagreement.
- Retest Rescan, close during Looking/no late popup + subsequent successful scan;
  after quiz close wait 15 s + >=2 s empty; 60 s hold; TTS separately by owner.
- Separate follow-ups: captured stdout omitted scan logs despite saved files;
  PET contradiction and Q5 fallback. No logging/quiz rewrite in this change.
