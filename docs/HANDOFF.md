# Handoff

- Base branch `feature/live-scan` at 5e350d6 (PR #17 M2c merge 4de8947; docs PRs
  #18 and #19 merged). This handoff: branch `docs/handoff-final`, PR into feature/live-scan.
- M2c merged after the owner's manual retest on 16 Oct (no recording, not log-verified).
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`.
  Every m2c-diagnostics JSONL line carries `appCommit`; check it matches.
- Never commit the user Xcode scheme or Maixcam.txt.
- Evidence: [M2c review](test-results/m2c-clean-image-review.md). Decisions:
  [0003](decisions/0003-stop-generation.md), [0011](decisions/0011-quiz-prefetch.md),
  [0012](decisions/0012-crop-identification-and-hazards.md).

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
- Tests: analyzer clean; 246 pass, 2 known stale splash failures. Real-model
  `integration_test/gemma_cancel_test.dart` 16 Oct (macOS, gemma-4-E2B-it): 4/4
  (M0.3, M0.4, M0.5a, M0.5b); cancel to stream close 2-43 ms mid-generation,
  713 ms during prefill; M0.3 one conclusive sample (attempt 3).

## Robot tests still to run

- Mismatch card (never seen on hardware); close-before-send `submit_skipped`
  (20:07 close came after send, logged `cancelled`); residu routing (Gemma never
  returned residu); 60 s visible hold with one object; chat during Looking.

## KNOWN OPEN (not done)

- M0.4 probes: 2 of 3 returned 5 options, quiz parse failed on both attempts.
  Check whether the parser/prompt expects 4 options (for M3).
- Image identify first token took 7-9 s in the test (vision encoder on CPU).
  Compare with the JSONL identify times.
- A chat interrupting a scan/prefetch waits up to 8 s for the cancelled call
  (decision 0003); real latency not measured.
- Preview hidden under Looking/B3/quiz sheets: accepted; small live preview in
  the overlay to design in M4 (rising frame counter shows the stream runs).
- No robot sorting path exists in the app (plan 2.6); cards don't drive the arm.
- 2 stale splash tests (`test/widget_test.dart`); `lib/Screens` vs `lib/screens` case.
- Dataset work (owner): laptop as E_Waste (was Cardboard 16 Oct); cup vs bottle.

## Next step: M3 question bank

- First: check the M0.4 5-option parse failures and run the temperature test
  (plan 1.3, [0005](decisions/0005-m0-findings.md)) before writing questions.
- Questions, answer keys and explanations grounded in the course module PDF
  with page/section references ([quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement)).
  Owner to supply the PDF; nothing implemented yet.
- Quiz follow-ups: duplicate/conflicting questions; Paper Q4 fallback (8273 ms).
