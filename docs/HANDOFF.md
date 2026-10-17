# Handoff

- Base branch `feature/live-scan` at ef405f9 (#21, #22 merged). Open: #23 label bank (0015),
  #24 grounded generator (draft, stays off). This task: `feat/m3-object-bank` (M3.5), cut from
  #23's head, PR into feature/live-scan.
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
  [0015](decisions/0015-question-bank-draft.md) ([review sheet](quiz-review/question_bank_review.md)),
  [0017](decisions/0017-object-bank.md) ([object review](quiz-review/object_bank_review.md)).

## What M3.5 delivers (feat/m3-object-bank)

- Questions come only from the bank (object -> label pool -> fixed fallback, no repeats); no question
  request reaches Gemma by default. `GEMMA_QUESTIONS=true` / `ESSAY_QUESTIONS=true` opt back in.
- 13 objects, 51 MC + 13 essays, all `draft`. Owner marks the review sheet; then add
  `status: accepted` and filter on it (not built). Check: `python3 scripts/validate_bank.py`.

## Earlier M3 (0013-0015)

- MC schema `correct` + 3 `wrong` (#21); 66 module chunks + label map in `assets/module/` (#22; PDF
  not committed, rebuild with `scripts/extract_module.py`); label-pool bank, 56 items (#23).

## M2c (PR #17, details in 0012)

- Lock -> clean crop -> Gemma identify -> B3 card -> quiz; three bins, mismatch gate,
  cancel fix. Real-model cancel test 16 Oct 4/4. Unit tests 255 pass, 2 stale splash.

## Robot tests still to run

- Mismatch card; close-before-send `submit_skipped`; residu routing; 60 s hold with one
  object; chat during Looking; M3.5 quiz (bank questions, header "SOAL DARI MODUL").

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

- Done: chunks (0014), label bank (0015), object bank wired in (0017). Next: owner review of
  both sheets ([quiz plan](pipeline/README.md#module-grounded-quiz-plan-owner-requirement)).
- Owner: module inconsistencies to review (composting steps, 7.3 vs the app, 6.6 superscripts),
  listed in the M3.2 results.
- Quiz follow-ups: duplicate/conflicting questions; Paper Q4 fallback (8273 ms).
