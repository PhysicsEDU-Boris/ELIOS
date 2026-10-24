# 0020: After a quiz, a different object may lock; lock diagnostics (M2d)

- Status: Accepted (owner decision: "a different object may lock")
- Date: 2026-10-20
- Replaces: the empty-scene re-arm and the 30 s same-label wait of
  [0008](0008-live-scan-state-machine.md).
- Code: `lib/services/live_scan_state_machine.dart` (rule, block reasons, events,
  `manualRearm`), `lib/services/detection_stabilizer.dart` (`reset`, candidate events),
  `lib/services/live_scan_controller.dart` (run log, filter events), `lib/services/scan_diagnostics.dart`
  (fixed id), `lib/widgets/live_scan_debug_overlay.dart` (reason text, "Scan lagi").
- Tests: `test/live_scan_state_machine_test.dart`, `test/live_scan_controller_test.dart`.

## Why

The 20 Oct robot recording (lock failure report, `~/Desktop/bank_vs_gemma_report.md`) spent about
6 minutes in COOLDOWN with objects detected at 83-95%: 110-188 s (bottle 86-93%), 258-327 s
(bottle 83-91%, laptop 93%), 438-552 s (bottle 83-95%), 604-727 s (banana peel 89-95%). After the
15 s cooldown the old rule also needed 2 s with **nothing** in view (score ≥0.50, hand excluded),
so any object left on the table blocked every new lock. It re-armed only when the camera swung
away. The overlay could not say why, and the JSONL had no lock events.

## Rule (after the 15 s cooldown)

- An object with a **different label** than a quizzed one may lock, even while other objects stay in view.
- An object with the **same label** waits until the quizzed object has been absent for 2 s.
- The quizzed object itself, held in view, is never quizzed again, also when its label flickers.
- A hand still counts as empty. All other thresholds are unchanged (0.70 / 0.55 / 0.50, 60% box,
  IoU 0.65, lock 1 s, dropout 0.6 s, stabilizer re-arm 1.5 s, cooldown 15 s).

### Layers

- **State machine (changed):** it remembers each quizzed object by its box, not by label. Each
  frame it follows them by overlap (IoU ≥0.3, any label); right after a quiz closes (camera paused)
  it finds each again by its label. Boxes overlapping a quizzed object (`same_object`) or carrying
  its label (`same_label`) are removed **before** the stabilizer. A quizzed object absent 2 s is
  forgotten. After the cooldown the machine re-arms on the next frame, without an empty scene.
- **Stabilizer (reset only):** its "while a locked object stays in view, other objects wait"
  rule is not changed. The quizzed object never reaches it after the quiz (filtered above), so
  its lock lapses. `reset()` on re-arm drops a lock or candidate formed while asks were refused
  (during the quiz or cooldown), which would otherwise block a different object.

### Consequences

- The 30 s label wait is gone: a quizzed object that leaves for 2 s and returns can be quizzed
  again (as the task asks). Before, it needed 30 s away.
- A failed or cancelled ask blocks its object until absent 2 s (was: stabilizer 1.5 s plus 30 s label wait).
- `ponytail:` objects are matched by box overlap only (no track ids until ByteTrack, M6). An
  object moved further than its own width between two analysed frames (~5 fps) is lost, and can
  be quizzed again after 2 s.

## Diagnostics (debug builds only)

One JSONL per app run, `m2c-diagnostics/livescan-<ms>.jsonl`, `appCommit` on every line, no
question text. Each event is written at most every 0.5 s; skipped ones are counted in `suppressed`.

| Event | Data |
|---|---|
| `cooldown_enter` | `cooldownMs`, `quizzed` labels |
| `rearm` | `reason` (`cooldown_elapsed`, `manual`), `sinceCloseMs`, `quizzed` |
| `rearm_blocked` | `reason` (`cooldown`, `same_object`, `same_label`), `labels` in view with score, `remainingMs`; once per change of reason or labels |
| `candidate_start` / `candidate_drop` | `label`, `score` / `reason` (`dropout`, `frame_gap`, `label_change`, `other_object`, `flicker_back`, `reset`) |
| `lock_dropped_same_label` | `reason`, blocked `labels`, `quizzed`; once per change |
| `quizzed_object_gone` | `label` (absent 2 s) |
| `box_ignored_too_large` | `labels` with area fraction, `maxAreaFraction`; once per change |
| `below_min_score` | `labels` in view under 0.70 with best score; at most once a second |
| `ask_busy` | `label` |
| `manual_rearm` | `state`, `quizzed`, `sinceCloseMs` |

The debug overlay shows the current reason in plain text (e.g. "menunggu: benda yang sudah dikuis
masih terlihat (Plastic 0.93)") and a "Scan lagi" button, enabled only when no quiz is open, that
ends the cooldown and forgets the quizzed objects. Release builds show neither (the overlay is
only built in debug) and write no log.

## Link drop (added 24 Oct, R1)

Found in the 24 Oct fake-MaixCAM2 test:

- A Plastic item was quizzed and stayed in view.
- The link dropped for 12 s.
- After the reconnect, a different Plastic item at the same spot stayed blocked as "benda yang
  sudah dikuis masih terlihat".

No frames arrive during a drop, so no absence can be timed, and the old memory never let go.

**Decision: on every reconnect, forget the quizzed objects of closed quizzes and reset the
stabilizer** (`LiveScanStateMachine.onLinkRestored`, called by the control screen on each new
connection).

- An open quiz, and the object it is about, are kept, so it is not asked again once it closes.
- A running cooldown is kept: it runs on the clock.

**Why not keep the memory:**

- During a drop the app cannot see anything, and the robot may have been driven: the scene
  before and after are unrelated.
- Keeping the memory blocks a new object for as long as anything overlaps the old box.
- Forgetting costs at most one repeat quiz of an object that stayed in view, after the 15 s
  cooldown. 0020 already accepts that for an object gone 2 s.

The `link_restored` diagnostic event records the state and the forgotten labels.

## J1 guard (added 24 Oct, E1)

Found with the fake MaixCAM2 (`j1_sweep_item_in_view`):

- The camera turned +25, -25 and back to 0 deg with a quizzed bottle in view.
- The bottle was out of view for more than 2 s, so it was forgotten.
- After the cooldown, the same bottle was quizzed again.

On the robot every pick turns J1 (the camera rides on it), so every sort would repeat a quiz.

**Rule:** while the arm moves, and for `ARM_SETTLE` (1.5 s) after, no frame is analysed. The
stabilizer neither locks nor re-arms, and no absence is counted for quizzed objects.

- "Arm moving" comes from:
  - the app's own servo commands (the largest angle change ÷ 60 deg/s; an unknown start counts
    as 180 deg);
  - the per-frame `arm_moving` field (0026; `null` until the firmware sends it).
- When the guard ends, each quizzed object is found again **by its label** (any position) and
  its absence restarts, like after a quiz. **Nothing is forgotten**: unlike a link drop, the
  scene is the same, only the camera turned.
- The stabilizer resumes through its frame-gap rule: a candidate from before the guard is
  dropped and has to hold 1 s again; a lock stays.
- The overlay says "menunggu: lengan bergerak". The `arm_guard` and `arm_settled` events go to
  the JSONL.
- Code: `LiveScanController.onArmCommand` / `onDetections(armMoving:)`,
  `LiveScanStateMachine.onArmSettled`.

This works with or without R1. R1's own lock-ignore during SORTING (0023) stays as it is.
