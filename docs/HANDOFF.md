# Handoff

- Base branch `feature/live-scan` at e3aa90d. PRs #21-#23 and #25-#29 merged; #24 (grounded quiz)
  stays an open draft (latency gate failed). Never commit the user Xcode scheme or Maixcam.txt.
- Robot build: `flutter build macos --debug --dart-define=LIVE_SCAN=true
  --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`, launch with `open`. Every JSONL line
  carries `appCommit`; check it matches.
- Decisions: [0013](decisions/0013-quiz-answer-schema.md) MC schema,
  [0014](decisions/0014-module-chunks.md) module chunks, [0015](decisions/0015-question-bank-draft.md)
  label bank, 0016 grounded quiz (on draft #24 only), [0017](decisions/0017-object-bank.md) object bank,
  [0018](decisions/0018-question-source-toggle.md) source switch,
  [0019](decisions/0019-gemma-question-topics.md) Gemma angles, [0020](decisions/0020-lock-rearm-rule.md)
  re-arm rule, [0021](decisions/0021-manual-driving-orchestration.md) driving + orchestration (proposed).

## M2d robot test (NOT run yet)

- Banana peel quizzed and left in view; a bottle locks 15 s after the quiz closes (overlay shows
  the cooldown, then "benda yang sudah dikuis masih terlihat").
- Second bottle waits until the first has been gone 2 s.
- "Scan lagi" (disabled while a quiz is open); B3 path; check the new `livescan-*.jsonl`.
- If repeat quizzes appear from detection flicker, raise `quizzedObjectAbsentToRearm` to 5-8 s.

## Quiz state

- Bank is the default source; Gemma mode is debug/experiment only (0018, 0019).
- All bank items are status `draft` and are served by default. Owner is reviewing
  [object_bank_review.md](quiz-review/object_bank_review.md) and
  [question_bank_review.md](quiz-review/question_bank_review.md).
- Next quiz task, after the review: accepted-filter (release serves only `accepted` items, drafts
  only in debug), plus kardus Q1 wording, level chip vs Mudah-first order, generic Q5,
  "menurut modul" wording.

## Next tasks, in order

1. P1 protocol: optional `track_id`, `dist_cm`, `arm_tags` (0021).
2. R1 orchestration (0021).
3. R2 sort modes (0021).
4. Emergency stop (before any real arm test).
5. CI.
6. Arm bring-up + ESP32 link (plan 2.6).
7. M4 overlay.
8. M5 Android.
9. M6 ByteTrack (conditional on the two-object overlap test).
10. M7 release hygiene.

## Known open

- Image identify first token 7-9 s (vision encoder on CPU).
- A chat interrupting a scan/prefetch waits up to 8 s for the cancelled call (0003).
- No robot sorting path exists yet; the arm is not working.
- 2 stale splash tests (`test/widget_test.dart`); `lib/Screens` vs `lib/screens` case.
- Dataset work (owner): laptop as E_Waste; yellow cup scores 39-56%.
