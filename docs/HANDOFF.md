# Handoff

- Base branch `feature/live-scan` at 3df0809. PRs #21-#23 and #25-#31 merged; T1 (fake MaixCAM2)
  is on `feat/t1-fake-maixcam` (PR open); #24 (grounded quiz) stays an open draft (latency gate failed). Never commit the user Xcode scheme or Maixcam.txt.
- Robot build: see CLAUDE.md, launch with `open`; check every JSONL line's `appCommit` matches.
- Decisions: [0013](decisions/0013-quiz-answer-schema.md) MC schema,
  [0014](decisions/0014-module-chunks.md) module chunks, [0015](decisions/0015-question-bank-draft.md)
  label bank, 0016 grounded quiz (on draft #24 only), [0017](decisions/0017-object-bank.md) object bank,
  [0018](decisions/0018-question-source-toggle.md) source switch,
  [0019](decisions/0019-gemma-question-topics.md) Gemma angles, [0020](decisions/0020-lock-rearm-rule.md)
  re-arm rule, [0021](decisions/0021-manual-driving-orchestration.md) driving + orchestration (proposed,
  amended 24 Oct), [0022](decisions/0022-detection-protocol-distance-tags.md) P1 protocol + topology,
  [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2 (0023 reserved for R1's command link).
- Topology (0021e): app -> MaixCAM2 only (WiFi); MaixCAM2 -> ESP32 (arm, 6 servos incl. J1) and
  Uno (wheels) over UART. The Mac is debug only.

## Fake MaixCAM2 (T1)

- `tools/fake_maixcam/` (README): main.py's protocol, robotic_hand_sim frames (9b2737e), 10
  scenarios; app config `127.0.0.1:8765`. Manual check on the macOS debug build: NOT run yet.

## M2d robot test (NOT run yet; the fake's scenarios cover most of it)

- Banana peel quizzed and left in view; a bottle locks 15 s after the quiz closes (overlay: the
  cooldown, then "benda yang sudah dikuis masih terlihat"); a second bottle waits 2 s.
- "Scan lagi" (off while a quiz is open); B3 path; `livescan-*.jsonl`. Repeat quizzes from
  flicker: raise `quizzedObjectAbsentToRearm` to 5-8 s.

## Quiz state

- Bank is the default source (Gemma: debug only, 0018/0019). All items are `draft` and served
  by default. Owner is reviewing
  [object_bank_review.md](quiz-review/object_bank_review.md) and
  [question_bank_review.md](quiz-review/question_bank_review.md).
- Next quiz task, after the review: accepted-filter (release: `accepted` only), kardus Q1, level
  chip vs Mudah-first, generic Q5, "menurut modul" wording.

## Next tasks, in order

1. **Next: R1 orchestration** (0021 + amendment); define the command link as 0023 and fill the
   fake's PICK/MOVE_TO_BIN/DROP/STOP/DRIVE TODOs. Firmware sends P1 fields only after calibration.
2. Camera calibration + firmware `dist_cm` / `arm_tags` (0022 spec).
3. R2 sort modes (0021).
4. Emergency stop (before any real arm test).
5. CI.
6. Arm bring-up: MaixCAM2 -> ESP32 UART (plan 2.6 superseded by 0021e).
7. M4 overlay.
8. M5 Android.
9. M6 ByteTrack (conditional on the two-object overlap test).
10. M7 release hygiene.

## Known open

- Image identify first token 7-9 s (vision encoder on CPU); a chat interrupting a scan waits up
  to 8 s for the cancelled call (0003).
- No robot sorting path yet; the arm is not working.
- 2 stale splash tests (`test/widget_test.dart`); `lib/Screens` vs `lib/screens` case. Dataset
  (owner): laptop as E_Waste; yellow cup scores 39-56%.
