# Handoff

- Base branch `feature/live-scan` at ef405f9 (M3.1 #21, M3.2 #22 merged). Open: #23 question bank
  draft (decision 0015). This task: `feat/m3-grounded-quiz` (M3.4), PR into feature/live-scan.
- M2c merged after the owner's manual retest on 16 Oct (no recording, not log-verified).
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`.
  Every m2c-diagnostics JSONL line carries `appCommit`; check it matches.
- Never commit the user Xcode scheme or Maixcam.txt.
- Evidence: [M2c review](test-results/m2c-clean-image-review.md). Decisions:
  [0003](decisions/0003-stop-generation.md), [0011](decisions/0011-quiz-prefetch.md),
  [0012](decisions/0012-crop-identification-and-hazards.md),
  [0013](decisions/0013-quiz-answer-schema.md) ([M3.1 results](test-results/m3-quiz-parse.md)),
  [0014](decisions/0014-module-chunks.md) ([M3.2 results](test-results/m3-module-chunks.md)),
  [0016](decisions/0016-grounded-quiz.md) ([M3.4 results](test-results/m3-grounded-quiz.md)).

## What M3.4 delivers (feat/m3-grounded-quiz), NOT shipped

- `GROUNDED_QUIZ=true` (default off): retriever -> 2-3 module passages per question -> Gemma must
  quote verbatim + name the object, else retry/fallback. Fallbacks no longer repeat (always on).
- Real model: B shows 22/30 grounded questions vs A 30/30 ungrounded; **question 1 p50 8.1 s,
  over the 6 s gate** (retries, not prompt size; 300 words was slower). Next: snap near-verbatim
  quotes, lower grounded temperature, re-measure. Owner: fill `quiz-review/grounded_sample_review.md`.

## M3.1 / M3.2 (PRs #21, #22; 0013, 0014)

- MC asks for `correct` + 3 `wrong` (5-option failures 0/17). 66 module chunks + label map in
  `assets/module/` (PDF not committed; rebuild with `scripts/extract_module.py`).

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
- Done: chunks (0014), bank draft (#23, 0015), grounded quiz behind a flag (0016, gate failed).
- Owner: module inconsistencies to review (composting steps, 7.3 vs the app, 6.6 superscripts),
  listed in the M3.2 results.
- Quiz follow-ups: duplicate/conflicting questions; Paper Q4 fallback (8273 ms).
