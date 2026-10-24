# Handoff

- Base `feature/live-scan` at 66ca897 (PRs up to #33 merged); B1 is on `feat/b1-bank-detector-class`
  (PR open). #24 stays a draft. T1b (photo cards) was not started. Never commit the Xcode scheme or Maixcam.txt.
- Robot build: see CLAUDE.md, launch with `open`; check every JSONL line's `appCommit` matches.
- Decisions: [0013](decisions/0013-quiz-answer-schema.md) MC schema,
  [0014](decisions/0014-module-chunks.md) module chunks, [0015](decisions/0015-question-bank-draft.md)
  label bank, 0016 grounded quiz (on draft #24 only), [0017](decisions/0017-object-bank.md) object bank,
  [0018](decisions/0018-question-source-toggle.md) source switch,
  [0019](decisions/0019-gemma-question-topics.md) Gemma angles, [0020](decisions/0020-lock-rearm-rule.md)
  re-arm rule, [0021](decisions/0021-manual-driving-orchestration.md) driving + orchestration (proposed,
  amended 24 Oct), [0022](decisions/0022-detection-protocol-distance-tags.md) P1 protocol + topology,
  [0023](decisions/0023-r1-command-link.md) R1 + command link, [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2,
  [0025](decisions/0025-bank-detector-class.md) detector class picks bank questions.
- Topology (0021e): app -> MaixCAM2 only (WiFi); MaixCAM2 -> ESP32 (arm, 6 servos incl. J1) and Uno
  (wheels) over UART; the arm is not working yet. The Mac is debug only.

## R1 (0023)

- Built and tested on `SimulatedRobot` only. The app shows the link probe only (`--dart-define=R1=true`):
  today's firmware answers nothing, so "R1: robot tidak terhubung" and the live scan as before.
- Waits on R1-fw (the firmware command link) and the M4 screens for the student flow.
- Fake MaixCAM2 (T1, `tools/fake_maixcam/` README): app config `127.0.0.1:8765`; the owner used it
  on 24 Oct on the Mac (found B1 and the reconnect rule).

## M2d robot test (NOT run yet; the fake's scenarios cover most of it)

- Banana peel quizzed and left in view; a bottle locks 15 s after the quiz closes (overlay: the
  cooldown, then "benda yang sudah dikuis masih terlihat"); a second bottle waits 2 s.
- "Scan lagi" (off while a quiz is open); B3 path; `livescan-*.jsonl`. Repeat quizzes from
  flicker: raise `quizzedObjectAbsentToRearm` to 5-8 s.

## Quiz state

- Bank is the default source, every launch (Gemma: debug only, not saved, 0018/0019). Live scans
  pick bank questions by the detector class (0025); `class_mismatch` lines show Gemma disagreeing. All items are
  `draft`; owner is reviewing [object](quiz-review/object_bank_review.md) and [question](quiz-review/question_bank_review.md) banks.
- Next quiz task, after the review: accepted-filter (release: `accepted` only), kardus Q1, level
  chip vs Mudah-first, generic Q5, "menurut modul" wording.

## Next tasks, in order

1. **Next: emergency stop** (before any real arm test; also gate the `servo` sliders while R1 sorts).
2. R1-fw: the 0023 command link in `main.py` (+ the fake's PICK/MOVE_TO_BIN/DROP), then arm bring-up
   over the ESP32 UART (plan 2.6 superseded by 0021e).
3. Camera calibration + firmware `dist_cm` / `arm_tags` (0022 spec).
4. M4 overlay, including R1's student screens. 5. R2 sort modes. 6. CI.
7. T1b photo cards for the fake.
8. M5 Android.
9. M6 ByteTrack (conditional on the two-object overlap test).
10. M7 release hygiene.

## Known open

- Image identify first token 7-9 s (vision encoder on CPU); a chat interrupting a scan waits up
  to 8 s for the cancelled call (0003).
- 2 stale splash tests (`test/widget_test.dart`); `lib/Screens` vs `lib/screens` case. Dataset
  (owner): laptop as E_Waste; yellow cup scores 39-56%.
