# Handoff

- Base branch `feature/live-scan` at b5499d2 (PR #17 M2c merge 4de8947; docs PRs
  #18-#20 merged). M3.1 PR #21 (`feat/m3-quiz-parse`) open, not merged. This task:
  `feat/m3-module-chunks` (M3.2), branched from #21, PR into feature/live-scan.
- M2c merged after the owner's manual retest on 16 Oct (no recording, not log-verified).
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`.
  Every m2c-diagnostics JSONL line carries `appCommit`; check it matches.
- Never commit the user Xcode scheme or Maixcam.txt.
- Evidence: [M2c review](test-results/m2c-clean-image-review.md). Decisions:
  [0003](decisions/0003-stop-generation.md), [0011](decisions/0011-quiz-prefetch.md),
  [0012](decisions/0012-crop-identification-and-hazards.md),
  [0013](decisions/0013-quiz-answer-schema.md) ([M3.1 results](test-results/m3-quiz-parse.md)),
  [0014](decisions/0014-module-chunks.md) ([M3.2 results](test-results/m3-module-chunks.md)).

## What M3.2 delivers (feat/m3-module-chunks)

- Module PDF (main ce9854c, sha 5fd520fd…, not committed) -> 66 verbatim chunks in
  `assets/module/module_chunks.json` via `scripts/extract_module.py` (pypdf 5.1.0).
  Re-run: put the PDF in docs/module/, then `python3 scripts/extract_module.py` and
  `python3 scripts/test_extract_module.py`.
- `assets/module/label_to_chunks.json`: 9 classes; Cardboard/Paperboard partial,
  the rest covered. Bundled; not used by the quiz yet (M3.3).

## M3.1 (PR #21, details in 0013)

- MC asks for `correct` + 3 `wrong`: 5-option failures 0/17; parse 74% -> 88%; temperature stays 0.9.

## M2c (PR #17, details in 0012)

- Lock -> clean crop -> Gemma identify -> B3 card -> quiz; three bins, mismatch gate,
  cancel fix. Real-model cancel test 16 Oct 4/4. Unit tests 255 pass, 2 stale splash.

## Robot tests still to run

- Mismatch card; close-before-send `submit_skipped`; residu routing; 60 s hold with one
  object; chat during Looking; M3.1 quiz (4 options, no 5-option rejects in the log).

## KNOWN OPEN (not done)

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

- Done: 5-option parse fix + temperature test (0013). Not yet re-run on the robot.
- Done: module chunks + label map (0014). Next (M3.3): questions, keys and explanations from
  the chunks with page/section refs ([quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement)).
- Owner: module inconsistencies to review (composting steps, 7.3 vs the app, 6.6 superscripts),
  listed in the M3.2 results.
- Quiz follow-ups: duplicate/conflicting questions; Paper Q4 fallback (8273 ms).
