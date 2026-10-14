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
| any state but ASKING | a quiz is open that the machine didn't start (also a minimized one) | QUIZ |
| QUIZ | quiz closed (phase back to `idle`) | COOLDOWN |
| COOLDOWN | 15 s since the close **and** no lockable detection for 2 s | SEARCHING |

- **Locks during ASKING and QUIZ are dropped, not queued.** A dropped lock
  still counts as locked in the stabilizer, so that object isn't asked
  later either.
- **COOLDOWN asks nothing**, not even a different object (changed after
  the robot test, see "Cooldown" below).

### Cooldown (added 2026-10-14, after the robot test)

The robot recording showed a second Paperboard quiz about 2 s after the
first one closed. The stabilizer alone couldn't stop it: when the camera
moves, the same object lands in a different place (box overlap below 0.65)
and counts as new, and an object that leaves re-arms after only 1.5 s.
Three rules now apply, as named constants in `live_scan_state_machine.dart`:

| Constant | Value | Rule |
|---|---|---|
| `quizCooldown` | 15 s | No ask for this long after any quiz closes. |
| `emptySceneToRearm` | 2 s | COOLDOWN also needs an empty scene (nothing *present*, see "Presence" below) for this long, still true when the 15 s are over. A lock dropped during COOLDOWN is therefore re-armed in the stabilizer (absent ≥ 1.5 s) before the machine searches again. |
| `sameLabelWait` | 30 s | A label that had a quiz isn't asked again until it has been **absent from the scene for 30 s** (changed 2026-10-14, see "Presence"; it was 30 s from the ask or quiz close). While the label is present the wait keeps restarting. The lock is dropped; the stabilizer keeps that object locked until it leaves. |

- **Any open quiz is QUIZ.** The machine is told about every quiz phase,
  including the current one when the control screen opens, so a quiz it
  didn't start (or a minimized one) shows QUIZ and nothing is asked. Its
  close starts the same cooldown.
- **BUSY is counted separately.** An ask refused because a quiz was open
  never reached Gemma: it adds to `busyCount`, not to the identify count,
  and doesn't start the label wait.
- **Ask condition** (in `LiveScanController`): score at least **0.70**
  (`minScore`, was 0.55), and a box covering more than **0.6** of the frame
  (`maxBoxAreaFraction`) is ignored. The robot sends near-full-frame boxes
  that are rarely one real object.
- All values are first guesses from one recording; tune them on the robot.

### Presence, label wait and hysteresis (added 2026-10-14, second robot test)

A 9-minute robot recording with the rules above showed the same object
asked again (a box 3 times, a battery twice), each time allowed by the
rules: the 30 s counted from the quiz close, and a held battery whose
score dipped under 0.70 for about 2 s counted as an empty scene. Items
whose score hovers at 0.55–0.69 (a clear bottle, a red mouse) took 30–55 s
to lock. Owner's decisions:

| Constant | Value | Rule |
|---|---|---|
| `minScore` | 0.70 | Unchanged: the score needed to **start** a lock. |
| `presenceScore` | 0.50 | A box at this score or more, at most 0.6 of the frame, and not `Human_Hand`, means "something is in the scene". Only a scene with none of those is empty. Presence never starts or continues a lock. |
| `keepLockScore` | 0.55 | Hysteresis: once a label was seen at `minScore`, its boxes keep counting for the lock down to 0.55, as long as the label doesn't stay under 0.55 longer than the stabilizer's dropout tolerance (600 ms). Never starts a lock. |

- **Same label = same object, for quizzes only (owner's Q1, Q2).** The wait
  is per label, with no box-overlap check: two Plastic bottles count as one
  object. Per-object identity comes later from the robot's tracking ids
  (plan 2.4/2.5). **This anti-spam is for quizzes only: future robot
  sorting must not be gated by it.**
- **Absence** means no box of that label at `presenceScore` or more (box at
  most 0.6 of the frame). Each present label's last-seen time is updated on
  every frame, **also while a quiz is open** (QUIZ, including a minimized
  quiz, owner's Q3). Nothing is locked or asked during QUIZ.
- **A swap during an open quiz** (bottle A out, bottle B in) is just the
  label still present (Q4). After the close, the label still needs 30 s of
  absence before it can be asked.
- **The camera pauses while the quiz covers it**, so absence can't be
  measured then: on close, every label seen since the quiz started counts as
  seen at the close.
- **Overlay:** the labels still waiting and the seconds left, for example
  `wait Plastic 12s` (stays at 30 s while the label is in view).
- The stabilizer's lock, overlap and dropout rules are unchanged.

### Wait freeze during a quiz (fixed 2026-10-14, third robot test)

A third recording, on the build above, still showed the box re-asked —
twice more, four times in one 9-minute run. Cause: `labelWaits` (read by
the debug overlay on every rebuild, including during a quiz, since
`onQuizPhase` calls `notifyListeners()` on each phase change) called the
same mutating check `onFrame` used to expire a wait. The camera pauses
during a quiz, so a label's last-seen time never refreshes then; once the
overlay's own reads pushed the elapsed time past `sameLabelWait`, the
label was silently dropped from the waiting set **before the quiz closed**
— confirmed in the recording: the `wait Cardboard …s` line vanished mid-quiz
whenever a quiz ran longer than 30 s. After that, the box could be
re-asked as soon as the ordinary cooldown and empty-scene rules allowed,
defeating `sameLabelWait` entirely for any quiz over 30 s.

Fix, in `live_scan_state_machine.dart`:

- **`labelWaits` is now a pure read.** It never removes a label from the
  waiting set; only `onFrame` does that. While the machine is in ASKING or
  QUIZ, every waiting label reads the full `sameLabelWait`, since nothing
  can be asked until the quiz closes anyway.
- **Expiry is a sweep over every waiting label**, not just the ones in the
  current frame, run once per `onFrame` call, and skipped entirely while
  ASKING or QUIZ — so an open quiz can never lose a label's wait, however
  long it runs, including once M2b lets frames keep arriving during a quiz.
- **The sweep checks a label's previous last-seen time before this frame's
  own presence is recorded**, so a label reappearing exactly when its wait
  matures still unblocks on that same frame (unchanged from before this
  fix).

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

- **Score filter:** 0.70 to start a lock (was 0.55, the old path's value),
  0.55 to keep one (hysteresis), 0.50 to count as present; boxes over 0.6 of
  the frame are dropped. All before the stabilizer (see "Cooldown" and
  "Presence").
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
- the number of identify calls (quiz starts) and of asks refused as busy
- the first-token time of the last quiz start's question
- the labels waiting for `sameLabelWait`, with the seconds left

That time comes from the new read-only
`GemmaQuizService.lastFirstTokenMs`, set on the existing log line (owner's
decision 3). It is the only production-service change in M2a.

Known limits:

- **fps doesn't update while the stream is paused** (no frames arrive).
- **The first-token time can be stale:** if the first question produced no
  token (fallback question), it shows the previous generation's time.

## Out of scope

- Camera pause during the quiz (fixed by decision 0009), and hazard handling
  (M2b, still open).
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
