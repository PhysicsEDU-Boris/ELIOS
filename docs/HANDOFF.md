# Handoff

- Base branch `feature/live-scan` at b5499d2 (PR #17 M2c merge 4de8947; docs PRs
  #18-#20 merged). This task: branch `feat/m3-quiz-parse` (M3 step 1), PR into feature/live-scan.
- M2c merged after the owner's manual retest on 16 Oct (no recording, not log-verified).
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`.
  Every m2c-diagnostics JSONL line carries `appCommit`; check it matches.
- Never commit the user Xcode scheme or Maixcam.txt.
- Evidence: [M2c review](test-results/m2c-clean-image-review.md). Decisions:
  [0003](decisions/0003-stop-generation.md), [0011](decisions/0011-quiz-prefetch.md),
  [0012](decisions/0012-crop-identification-and-hazards.md),
  [0013](decisions/0013-quiz-answer-schema.md) ([M3.1 results](test-results/m3-quiz-parse.md)).

## What M3 step 1 delivers (feat/m3-quiz-parse)

- Multiple choice now asks for `correct` + 3 `wrong`; the key is the `correct`
  field, so the 5-option failure is gone (0 of 17 real-model attempts). Parse
  74% -> 88% of attempts, questions 14/15 -> 15/15 (same 5 prompts x 3 temps).
- Temperature stays 0.9 (no clear winner at n=5). Remaining rejects are JSON
  syntax (trailing comma, unclosed array), absorbed by the 2-attempt retry.

## What M2c delivers (PR #17, details in 0012)

- Lock -> clean crop of the same frame -> Gemma identify -> B3 card -> quiz.
  Three bins with hazard veto; detector-vs-Gemma mismatch gate (hard examples
  logged); cancel fix (no submit after close, slot busy until the call ends).
- Real-model `gemma_cancel_test.dart` 16 Oct: 4/4 (cancel close 2-43 ms
  mid-generation, 713 ms in prefill). Unit tests now 253 pass, 2 stale splash.

## Robot tests still to run

- Mismatch card (never seen on hardware); close-before-send `submit_skipped`
  (20:07 close came after send, logged `cancelled`); residu routing (Gemma never
  returned residu); 60 s visible hold with one object; chat during Looking.

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
- Questions, answer keys and explanations grounded in the course module PDF
  with page/section references ([quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement)).
  Owner to supply the PDF; nothing implemented yet.
- Quiz follow-ups: duplicate/conflicting questions; Paper Q4 fallback (8273 ms).
