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
| `iouThreshold` | 0.65 | Plan range 0.6–0.7. Same label and box overlap ≥ 0.65 between frames counts as the same object. Hand jitter keeps the overlap above it; a different object is usually far below. |
| `dropoutTolerance` | 300 ms | The detector misses single frames; an absence up to 300 ms keeps the timer, a longer one starts it over (plan 1.2). |
| `rearmAfter` | 1.5 s | After a lock, the same object is ignored until it has been missing this long, or its label changes (plan 1.2). |
| `ignoredLabels` | empty | Labels dropped before tracking (exact match after trimming). M2 sets this. For example, `{Human_Hand}` keeps the hand holding the item from being tracked, locked, or winning the box choice. No class names are hard-coded. |

All of these are **provisional**. They come from the plan, not from
measurements on the real camera.

### How absence is measured (decision for review)

Absence is measured **from the first frame that arrives without the
object**. Time in which no frames arrive at all does not count. Two reasons:

- **Frame rate.** The plan runs analysis at 2–4 fps, so 250–500 ms between
  frames. If the gap were measured from the last sighting, frames 500 ms
  apart would count as a 500 ms dropout, and at 2 fps nothing would ever
  lock.
- **Pausing during a quiz (M2).** Analysis pauses while a quiz is open.
  With this rule, a locked object that is still there when analysis resumes
  stays locked, so it doesn't trigger a second quiz. A test covers this.

The cost: if analysis pauses while an object is a candidate, not yet
locked, its timer continues when frames resume. M2 should start a new
stabilizer, or clear it, when it resumes analysis after a long pause.

Boundaries: dropout `> 300 ms` resets (299 ms keeps, 301 ms resets). Re-arm
at `≥ 1500 ms`. Lock at `≥ 1000 ms` (exactly 1000 ms locks).

### Object identity

- **If both detections have a `trackId`,** it decides; the box may jump.
  This is the hook for ByteTrack on the MaixCAM2 (plan 2.5).
- **Otherwise** (old firmware, or one side without an id), box overlap
  decides.
- **A label change on the same object** always starts a new candidate, or
  re-arms a locked object.
- `trackId` isn't parsed from the robot's JSON yet (`Detection` has no such
  field). Parsing `track_id` is plan item 2.4, with its own commit, and old
  firmware must still work.

### Several boxes per frame: the most confident one

The stabilizer follows **one object at a time** (single target):

1. If the current candidate is still in view, keep following it, even if
   another box now scores higher. Otherwise scores that flip between frames
   would restart the timer forever.
2. Otherwise, take the **most confident** box. On equal scores, take the
   **larger** one.
3. While a locked object stays in view, other objects wait. A second object
   can lock only after the first leaves view (it doesn't need to be
   re-armed first).

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

## Consequences

- No production behaviour changes in M1: only the test imports the file.
- When M2 wires it in, re-check the parameters against the real camera and
  update this record.
