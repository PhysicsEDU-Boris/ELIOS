# Handoff

- Base branch `feature/live-scan` at 4de8947. M2c merged by PR #17 (merge 4de8947)
  after the owner's manual retest on 16 Oct (no recording, not log-verified).
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`.
  Every m2c-diagnostics JSONL line carries `appCommit`; check it matches.
- Never commit the user Xcode scheme or Maixcam.txt.
- Evidence: [M2c review](test-results/m2c-clean-image-review.md); decision 0012.

## What M2c delivers (PR #17)

- Live-scan lock -> clean (overlay-free) crop of the same robot frame -> Gemma
  identify -> B3 card for any hazard source -> quiz. Firmware
  `firmware/maixcam2/main.py` (sha bbb3595e…), MaixVision `app.yaml` tracked.
- Three bins (organik, anorganik, B3): Gemma category, hazard veto first, then
  nonhazardous residu -> anorganik as hardware fallback. Raw Gemma category and
  resolved bin logged separately.
- Detector-vs-Gemma mismatch gate: card with Pakai detektor / Pakai Gemma /
  Scan ulang; hard examples logged (`category_mismatch`, `mismatch_choice`).
- Cancel fix: no submit after a close; a running call's result is discarded
  and the Gemma slot stays busy until it ends (cap 8 s, decision 0003).
- Tests at merge: analyzer clean; 246 pass, 2 known stale splash failures.

## KNOWN OPEN (not done)

- Mismatch card never seen on hardware.
- Close-before-send `submit_skipped` not seen on hardware (16 Oct 20:07 close
  came after the photo was sent; that path was logged `cancelled` correctly).
- Residu routing not seen on hardware (Gemma never returned residu).
- Real-model `integration_test/gemma_cancel_test.dart`: run 16 Oct on macOS,
  real gemma-4-E2B-it: 4/4 passed (M0.3, M0.4, M0.5a, M0.5b). Cancel to stream
  close: 2-43 ms mid-generation, 713 ms when cancelled during prefill. M0.3 had
  one conclusive sample (attempt 3).
- M0.4 probes: 2 of 3 returned 5 options, quiz parse failed on both attempts.
  Check whether the parser/prompt expects 4 options (for M3).
- Image identify first token took 7-9 s in the test (vision encoder on CPU).
  Compare with the JSONL identify times.
- A chat that interrupts a scan or prefetch now waits up to 8 s for the
  cancelled call to end (decision 0003); real latency not measured.
- Preview hidden under Looking/B3/quiz sheets: accepted for now; a small live
  preview inside the new overlay is to be designed in M4. The rising frame
  counter is the evidence the stream runs.
- No robot sorting path exists in the app (plan 2.6); confirmation cards do
  not drive the arm.
- 2 stale splash tests in `test/widget_test.dart`.
- `lib/Screens` vs `lib/screens` directory case inconsistency.

## Dataset work (owner)

- Laptop should be detected as E_Waste (was Cardboard on 16 Oct afternoon).
- Cup vs bottle confusion.

## Next milestone: M3 question bank

- Questions, answer keys and explanations grounded in the course module PDF
  with page/section references ([quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement)).
  Owner to supply the PDF; nothing implemented yet.
- Known quiz follow-ups: duplicate/conflicting questions, Paper Q4 fallback
  (8273 ms generation; timeout cause not established).
