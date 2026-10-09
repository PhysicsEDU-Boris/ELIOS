# 0008: Live-scan state machine for the robot path (behind a switch)

- Status: Accepted
- Date: 2026-10-09
- Milestone: M2a (Notion plan 1.2, stage 3b, first part)
- Code:
  - `lib/services/live_scan_state_machine.dart` (pure logic)
  - `lib/services/live_scan_controller.dart` (glue)
  - `lib/widgets/live_scan_debug_overlay.dart`
  - wiring in `lib/Screens/control_screen.dart`
- Tests:
  - `test/live_scan_state_machine_test.dart`
  - `test/live_scan_controller_test.dart`
  - `test/widgets/live_scan_debug_overlay_test.dart`
  - `integration_test/live_scan_real_test.dart` (real model)

## Context

Today the robot path starts a quiz on the **first** frame with a detection
scoring at least 0.55. It then holds back the same label for 25 s
(`WasteQuizNotifier.onDetections`, `waste_quiz_provider.dart:139`), called
from `control_screen.dart` for every MaixCAM2 frame. The quiz's first Gemma
call is the first *question* (`_startSession` → `_loadQuestion` →
`generateQuestion`). The robot path never calls Gemma's `identifyItem`.

## Decision

### The switch, off by default

`--dart-define=LIVE_SCAN=true` routes MaixCAM2 detections through
`LiveScanController` instead of `onDetections`. **Without it, nothing
changes:** the old first-frame path runs as before.

It's off by default because the live scan hasn't been checked on the real
robot yet. The camera still pauses while the quiz is open (M2b changes that),
and hazard handling isn't done (M2b). Current users keep the known behaviour
until the manual checklist has passed on the device.

### What "ask" and "identify" mean here (owner's decision 1A)

- **A lock starts the quiz for the locked label** through the existing
  `WasteQuizNotifier.startForLabel`. That means one first-question request
  to Gemma; the quiz opens exactly as it does today.
- **"Identify calls" counts quiz starts.**
- **Robot frames still do not reach Gemma's identify:** the quiz uses the
  detector's label, as before. Sending the best crop to `identifyItem` is
  planned for **M2c**.

### States and transitions

| From | Event | To |
|---|---|---|
| SEARCHING | stabilizer has a candidate | LOCKING |
| LOCKING | candidate drops out | SEARCHING |
| SEARCHING / LOCKING | stabilizer lock | **ASKING**: exactly one quiz start for the locked label |
| ASKING | the quiz's first question is shown (phase `active`, also a fallback question) | QUIZ |
| ASKING | ask fails, is BUSY (a quiz is already open) or is cancelled (dismissed before the question) | SEARCHING (or LOCKING), with **ASK FAILED** in the overlay |
| QUIZ | quiz closed (phase back to `idle`) | COOLDOWN |
| COOLDOWN | the stabilizer re-arms: the quizzed object's lock ends (absent 1.5 s) | SEARCHING |
| COOLDOWN | a *different* object locks (that also means the old lock was replaced) | ASKING for the new object |

- **Locks during ASKING and QUIZ are dropped, not queued.** A dropped lock
  still counts as locked in the stabilizer, so that object isn't asked
  later either.
- **The stabilizer is the only judge of "same object".** It can't lock the
  same object twice before re-arming. A lock arriving in COOLDOWN is
  therefore always a new object or a held new label, which is why it is
  asked. This is what makes the acceptance row "object removed, a
  different one shown: a new lock and one new identify" work.

### On each failure

- **Failed, BUSY or cancelled ask (owner's decision 4a).** The machine goes
  back to searching, but the stabilizer keeps that object locked. It is
  blocked until it has been absent for 1.5 s, so a failing ask is not
  retried in a loop. Another object can be asked straight away. The overlay
  shows ASK FAILED until the blocked object re-arms. There is no
  `releaseLock()`.
- **No question ever arrives:** not possible today. `generateQuestion` has
  a 120 s timeout and then shows a fallback question, and closing the quiz
  counts as cancelled. So ASKING has no timeout of its own.
- **A chat message during ASKING (owner's decision 2a):** the existing
  reply, "Scan sampah dulu…", without calling Gemma, as today. The machine
  stays in ASKING and moves to QUIZ when the question arrives (tested). The
  rule that a user request cancels a scan is unchanged in the Gemma slot
  and proven in M0.5b.

### Inputs

- **Score filter:** the existing 0.55 minimum is kept and applied before
  the stabilizer.
- **Ignored labels:** `{'Human_Hand'}`, spelled exactly as the MaixCAM2
  firmware sends it (`LABELS` in `elio_maixcam2.py`, which is in the
  sandbox folder, not this repo).
- **Unknown labels:** in debug builds, each label that the app can't sort
  (no waste category from `ScannedWaste.fromLabel`) and doesn't ignore is
  logged once. This catches a wrong spelling such as `human_hand`. With the
  current firmware list, **`E_Waste`, `Paperboard` and `Tetra_Pak` have no
  category**. In particular, `E_Waste` is not mapped to hazardous. That's
  for M2b (hazard handling); not changed here.
- **Clock:** monotonic (`Stopwatch`-based), so a system clock change can't
  stop the stabilizer. This closes review finding 3 from M1.

### Debug overlay

Shown only in debug builds with the switch on. It shows:

- the state, or ASK FAILED
- frames analysed in the last second (fps)
- the number of identify calls (quiz starts)
- the first-token time of the last quiz start's question

That time comes from the new read-only
`GemmaQuizService.lastFirstTokenMs`, set on the existing log line (owner's
decision 3). It is the only production-service change in M2a.

Known limits:

- **fps doesn't update while the stream is paused** (no frames arrive).
- **The first-token time can be stale:** if the first question produced no
  token (fallback question), it shows the previous generation's time.

## Out of scope

- Camera pause during the quiz, and hazard handling (M2b).
- Identify on the robot crop (M2c).
- The phone capture-first path.
- `track_id` parsing (plan 2.4).
- Tuning the stabilizer on the device (M2, M5).

## Consequences

- The plan's acceptance rows for one object, and for a swapped object, are
  proven with scripted frames and a fake identify. The one-object row is
  also proven with the real model on the Mac.
- Switch it on by default only after the manual checklist passes on the
  robot (see the M2a pull request).
