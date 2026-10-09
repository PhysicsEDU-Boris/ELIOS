# 0007: Detection stabilizer (stage 3a)

- Status: Accepted. **The parameter values are provisional** until they are
  tuned on real devices: MaixCAM2 and the phone in M2, Android in M5.
- Date: 2026-10-09
- Milestone: M1 (Notion plan 1.2, stage 3a)
- Code: `lib/services/detection_stabilizer.dart`; tests:
  `test/detection_stabilizer_test.dart`

## Context

Today the robot path starts a quiz on the **first** frame that has a
detection scoring at least 0.55. It then holds back the same label for only
25 s (`WasteQuizNotifier.onDetections`, `waste_quiz_provider.dart:139`). The
phone path is capture-first: the user presses Scan
(`device_scan_screen.dart:57`). The plan replaces both with: lock on an
object held about 1 s, ask Gemma once, and don't ask again for the same
object.

## Decision

`DetectionStabilizer` turns per-frame detections into **one lock per
object**. It is pure logic: no timers, no camera, no Gemma, no TTS. Time
comes from an injected clock (`DateTime Function()`, default
`DateTime.now`). **Nothing in the app uses it yet;** wiring is M2.

### Parameters (all configurable)

| Parameter | Default | Why |
|---|---|---|
| `lockTime` | 1.0 s | Long enough to skip objects passing through, short enough to feel immediate (plan 1.2). |
| `iouThreshold` | 0.65 | Plan range 0.6–0.7. Same label and box overlap ≥ 0.65 between frames counts as the same object. |
| `dropoutTolerance` | **600 ms** | Must cover **one missed frame at 2 fps**, the slowest planned analysis rate. A frame that arrives without the object is a missed frame. The first value, 300 ms, reset the timer on any single miss at 2 fps (500 ms). |
| `rearmAfter` | 1.5 s | After a lock, the same object is ignored until it has been missing this long (plan 1.2). |
| `maxFrameGap` | 1.5 s | If no frame at all arrives for longer than this (for example analysis was paused), the unlocked candidate and its timer are dropped (see "Pauses"). |
| `ignoredLabels` | empty | Labels dropped before tracking (exact match after trimming). M2 sets this. For example, `{Human_Hand}` keeps the hand holding the item from being tracked, locked, or winning the box choice. No class names are hard-coded. |

All of these are **provisional** until they are tuned on a real device (M2, M5).

### How absence is measured

- Absence is measured **from the first frame that arrives without the
  object**. Time in which no frames arrive at all does not count. That
  makes the rule independent of the frame rate. Measuring from the last
  sighting would turn 2 fps frames (500 ms apart) into a 500 ms gap every
  time.
- Boundaries:
  - dropout: `> 600 ms` resets (599 ms keeps, 601 ms resets)
  - re-arm: at `≥ 1500 ms`
  - lock: at `≥ 1000 ms` (exactly 1000 ms locks)
- A dropout doesn't pause the lock timer. If the object comes back within
  the tolerance, it can lock on that frame.

**Known limit, decision for the owner:** no time tolerance can make
"one missed frame keeps, two missed frames reset" true at both 2 and 4 fps.
Two misses at 4 fps (absence 500 ms) last exactly as long as one miss at
2 fps (500 ms). With 600 ms (tested):

| Stream | 1 missed frame | 2 missed frames | 3 missed frames |
|---|---|---|---|
| 2 fps | keeps (500 ms) | resets (1000 ms) | resets |
| 4 fps | keeps (250 ms) | **keeps** (500 ms) | resets (750 ms) |

Only counting missed frames, instead of time, can reset on two misses at
both rates. That would replace `dropoutTolerance` with a frame count, and
is the owner's call.

### Pauses (no frames at all)

- **The candidate:** if the gap since the previous frame is longer than
  `maxFrameGap` (1.5 s), the unlocked candidate and its timer are dropped.
  Without this, an object that was a candidate for 0.5 s before a 20 s
  pause would lock on the very first frame after it (tested). A gap of
  exactly 1.5 s keeps the candidate; 1501 ms drops it.
- **A locked object** stays locked across any pause, and the pause doesn't
  count as its absence. This includes an object that was already missing
  just before the pause (tested). This matters for M2, which pauses
  analysis while a quiz is open: the object that triggered the quiz must
  not trigger it again.

### Label changes

- **On a candidate**, a label change on the same object starts a new
  candidate at once (the timer restarts).
- **On a locked object**, a label change does not re-arm it at once. The new
  label must hold for `lockTime` like any candidate; when it locks, it
  replaces the old lock. If the locked label comes back first, the
  new-label candidate is dropped.
- So a one-frame flicker (Plastic, Paper, Plastic) gives exactly one lock,
  and a real change that holds for 1 s gives one more (both tested). This
  fixes review finding 1: the first version re-armed on any label change,
  so a single flicker produced a second quiz for the same object.

### Object identity

- **If both detections have a `trackId`,** it decides; the box may jump.
  This is the hook for ByteTrack on the MaixCAM2 (plan 2.5).
- **Otherwise** (old firmware, or one side without an id), box overlap
  decides.
- **A label change on the same object** starts a new candidate. On a locked
  object, the new label must hold for the lock time before it replaces the
  lock (see "Label changes").
- `trackId` isn't parsed from the robot's JSON yet (`Detection` has no such
  field). Parsing `track_id` is plan item 2.4, with its own commit, and old
  firmware must still work.

### Several boxes per frame: the most confident one

The stabilizer follows **one object at a time** (single target):

1. If the current candidate is in view, keep following it, even if another
   box now scores higher. Otherwise scores that flip between frames would
   restart the timer forever.
2. If the candidate is **missing but still inside the dropout window**,
   wait for it and don't switch to another visible object, so its grace is
   kept (review finding 2, tested). Once the window passes, another object
   may become the candidate.
3. Otherwise, take the **most confident** box. On equal scores, take the
   **larger** one.
4. While a locked object stays in view, other objects wait. A second object
   can lock only after the first leaves view.

"Most confident" was chosen over "largest" because:

- **it's what the app does today:** `onDetections` takes the highest score
- **it's the detector's own measure:** the score is how sure the detector is
  of this label, which is what the quiz is about
- **largest has a known problem:** the largest box is often the hand or the
  background, though `ignoredLabels` covers the hand.

## Out of scope for M1

- **Wiring into the app (M2):** the state machine
  SEARCHING → LOCKING → ASKING → QUIZ → COOLDOWN, the TTS slot, keeping the
  camera alive, and mapping `Detection`/`CapturedFrame` to
  `TrackedDetection`.
- **Score threshold:** the 0.55 minimum score stays with the caller. M2
  filters before calling, as `onDetections` does today.
- **Phone path by image similarity:** it plugs in through `trackId`. A
  component that compares frames gives an object the same id while the
  frames look alike; the stabilizer needs no change for it. M1 does not
  implement that component.
- **Parsing `track_id`** (plan 2.4) and **ByteTrack** (plan 2.5).
- **Tuning the parameters** on real devices (M2, M5).
- **A monotonic clock** (review finding 3). The default clock is
  `DateTime.now`, so if the system clock is set back, frames are ignored
  until it catches up. M2 should inject frame timestamps or a
  `Stopwatch`-based clock when it wires the stabilizer in.

## Consequences

- No production behaviour changes in M1: only the test imports the file.
- When M2 wires it in, re-check the parameters against the real camera and
  update this record.
