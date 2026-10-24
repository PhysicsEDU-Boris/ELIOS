# 0023: R1 orchestration and the app-to-MaixCAM2 command link

- Status: Accepted for the app side (built and tested on the simulator). The firmware side
  (`firmware/maixcam2/main.py`) is a later task, R1-fw; the current firmware has no command link.
- Date: 2026-10-24
- Builds on: [0020](0020-lock-rearm-rule.md), [0021](0021-manual-driving-orchestration.md)
  (with amendments a-f), [0022](0022-detection-protocol-distance-tags.md),
  [0024](0024-fake-maixcam-sim.md).
- Code: `lib/services/robot/`:
  - `r1_orchestrator.dart`: the state machine;
  - `robot_controller.dart`: `RobotController`, `MaixCamRobot`, `ArmFeedback`, `ObjectIdentity`;
  - `simulated_robot.dart`;
  - `r1_constants.dart`.
- Tests: `test/r1_orchestrator_test.dart`; `tools/fake_maixcam/test_fake_maixcam.py`
  (`test_command_link_0023_shape`).

## Topology (0021 amendment e)

The app runs R1 and talks only to the MaixCAM2, over the live-scan WebSocket.

The MaixCAM2 forwards:

- arm commands to the ESP32 (all six servos, including J1);
- wheel commands to the Arduino Uno.

Neither slave has feedback, a heartbeat or a stop command. Every "done" therefore comes from the
MaixCAM2, which knows when it sent the angles and how long they take at 60 deg/s.

## Messages

App to MaixCAM2: one JSON message per command, with `seq` rising by one per command.

| `cmd` | Arguments | MaixCAM2 does | Replies |
|---|---|---|---|
| `STATUS` | — | nothing; the app probes the link with it | `ack` (may carry `drive_locked`) |
| `LOCK_DRIVE` | — | stops the wheels (Uno 0,0), then drops every `motor` message | `ack` |
| `UNLOCK_DRIVE` | — | forwards `motor` again | `ack` |
| `PICK` | `dist_cm`, `lateral_cm` (null if unknown) | IK to the object's floor spot, grip, lift | `ack`, `motion_done` |
| `MOVE_TO_BIN` | `bin`: `organik` / `anorganik` / `b3` | moves to that bin's fixed pose | `ack`, `motion_done` |
| `DROP` | — | opens the gripper, returns the arm home (J1 forward) | `ack`, `motion_done` |
| `HOLD` | — | resends the arm's current (interpolated) angles: it stops where it is. **Never detaches a servo** (no empty fields). | `ack`, `motion_done` |
| `STOP` | — | stops sending new angles (the arm holds its last line) and abandons the running command | `ack` |

- **DRIVE is the existing `motor` message.** The control screen already drives:
  `{"cmd":"motor","left":L,"right":R}` from its D-pad (`RobotControlNotifier.sendMotor`). It
  keeps its shape, has no `seq` and gets no reply. A new DRIVE message would only duplicate it.
- The app's `servo` sliders are unchanged. Gating them during SORTING is part of the
  emergency-stop and teleop work.

MaixCAM2 to app:

- `{"event":"ack","seq":n}` when the command is accepted;
- `{"event":"motion_done","seq":n}` when the MaixCAM2's own motion time for it has elapsed;
- `{"event":"error","seq":n,"reason":"..."}`, with reason `busy`, `unknown_cmd`, `bad_args`,
  `not_implemented`, `unreachable`, ...;
- `arm_tags` keep riding on frames (0022).

Replies are matched by `seq`. Late or unknown `seq` values are ignored. Uppercase command names
keep the link apart from the lowercase legacy commands.

**Firmware duties (R1-fw):**

- When the last client disconnects, the MaixCAM2 itself:
  - sends `STOP` to the arm (stops sending new angles);
  - unlocks driving and stops the wheels.
- It never sends an empty servo field: detaching would drop the arm.

## Timeouts and old firmware

Every awaited reply has a deadline:

- `ack`: `ACK_TIMEOUT` (2 s);
- `motion_done`: `ARM_TIMEOUT` (15 s) after the ack.

A missing reply ends the session in the safe state. On every (re)connect the app sends `STATUS`:

- With no `ack` within 2 s (today's firmware, which silently ignores unknown commands), R1 reports
  **"robot tidak terhubung"**, takes no lock, and the live scan and the quiz work exactly as
  without R1.
- Nothing in the app waits on the link otherwise, so old firmware cannot hang or crash it.

## States (0021, as built)

`SEARCHING` → `OBJECT_IN_VIEW` → `IDENTIFYING` → (`CONFIRM`) → `ASK_BIN` → `REVEAL` → `POSITION`
→ `READY` → `SORTING` → `WAIT_BOTH` → `RESUME`, then back to `SEARCHING`.

- **OBJECT_IN_VIEW**
  - Entered on the camera lock (stabilizer + 0020).
  - Driving is locked in two places: the app stops sending `motor`, and it sends `LOCK_DRIVE`.
  - The screen says "Berhenti". The session moves on when `LOCK_DRIVE` is acknowledged.
- **CONFIRM**
  - Only for B3, or a detector/Gemma mismatch.
  - The confirmation resolves the robot's bin (the hazard veto decides).
- **ASK_BIN / REVEAL**
  - The student's answer is recorded, but it **never** changes the robot's bin.
  - With no answer after `BIN_TIMEOUT` the bin is revealed anyway.
- **POSITION**
  - `dist_cm` inside `PICK_BAND_CM` (20-28): READY.
  - Outside it: "Maju sedikit" (too far) or "Mundur" (too close). Driving is unlocked for nudges
    only: `motor` capped at PWM 40.
  - Back inside the band: `LOCK_DRIVE` again, then READY.
  - `dist_cm` null (current firmware): a manual "Posisi sudah pas" button.
- **READY**: the student presses "Ambil". The arm never moves before this point, so never before
  REVEAL.
- **SORTING**, in parallel with OBJECT_QUESTIONS (2):
  - Steps: `PICK`, then the floor check, then `MOVE_TO_BIN`, then `DROP`.
  - **Pick done is decided only here**, when both hold:
    - `motion_done` for that PICK has arrived;
    - the object has left its floor spot: no box overlaps the spot with its bottom edge where it
      was, for 0.6 s, within 2 s.
  - `arm_tags` are kept as optional evidence only.
- **WAIT_BOTH**: the arm is done, or the questions are. Each question ends when it is answered,
  or after `QUESTION_TIMEOUT`.
- **RESUME**
  - Happens when both are done **and** `ARM_SETTLE` has passed since the last motion.
  - Driving is unlocked (`UNLOCK_DRIVE`), the host closes the quiz, and the live scan re-arms per
    0020.

**Human_Hand pauses the arm.**

- A hand box (score at least 0.5) during SORTING sends `HOLD`.
- The interrupted step is resent from its start once the hand has been out of view for 1 s.
- A hand in view when "Ambil" is pressed delays the first step the same way.
- Hand boxes are never filtered out, not even over the arm region.

**The camera turns with J1.**

- While SORTING / WAIT_BOTH, and for `ARM_SETTLE` after the last motion or an arm stop, R1:
  - takes no lock;
  - reports `ignoresLiveScanLocks`;
  - removes boxes over the arm region (`filterForLiveScan`).
- RESUME waits for the settle time, so the re-arm cannot happen inside it.

**Every exit** goes through one path: a timeout, an error reply, a failed pick, a link loss, or
the normal end. That path:

- sends `STOP` if the arm may be moving;
- unlocks driving: in the app at once; on the MaixCAM2 with `UNLOCK_DRIVE`, or at the reconnect
  when the link is down;
- tells the student, and returns to SEARCHING.

## Constants (`r1_constants.dart`)

| Constant | Value | Why |
|---|---|---|
| `BIN_TIMEOUT` | 15 s | 0021 |
| `QUESTION_TIMEOUT` | 20 s | 0021; counted from when the question shows |
| `OBJECT_QUESTION_COUNT` | 2 | 0021 |
| `PICK_BAND_CM` | 20-28 | 0021 amendment a (provisional) |
| `POSITION_TIMEOUT` | 60 s | proposed: covers POSITION and READY; a few cm of nudging plus one button press |
| `ARM_TIMEOUT` | 15 s per command after its ack | proposed: 180 deg takes 3 s at 60 deg/s; a PICK has about 4 segments |
| `ARM_SETTLE` | 1.5 s | proposed: servos and the camera settle; about 7 frames at 5 fps; same as the stabilizer's re-arm time |
| `WAIT_CAP` | 120 s, SORTING to RESUME | proposed: three arm commands of up to 15 s, two 20 s questions, hand pauses |
| `ACK_TIMEOUT` | 2 s | proposed: local WiFi round trip ≪ 1 s, plus a busy inference frame |
| `IDENTIFY_TIMEOUT` | 45 s | added: Gemma's identify reaches its first token in 7-9 s; this caps a slow full answer |
| `CONFIRM_TIMEOUT` | 30 s | added: a person must answer the confirmation card |
| `REVEAL` | 4 s | added: how long the revealed bin is shown |
| pick check | spot clear 0.6 s, within 2 s | added: the stabilizer's dropout tolerance |
| `HAND_CLEAR` | 1 s | added: a hand must be gone this long before the arm continues |
| nudge PWM | 40 | added: the control screen's default speed is 75 |
| arm region | x 0-0.15, y 0.35-0.65 of the frame | added, **provisional**: where the arm shows at J1 home in the sim; measure on the robot |

## Interfaces

- `RobotController` (the client of the MaixCAM2): `status`, `lockDrive`, `unlockDrive`, `pick`,
  `moveToBin`, `drop`, `hold`, `stop`, and `drive` (the gated `motor`). There is no heartbeat: the
  MaixCAM2 has none. Add one only if R1-fw adds it.
- `MaixCamRobot`: the 0023 messages over `WebSocketService.sendRobotCommand`; replies come from
  `WebSocketService.robotReplies`.
- `ArmFeedback`: `motionDoneSeq`, `objectLeftFloor` and `tags`, all nullable.
- `ObjectIdentity`: box overlap (IoU 0.3, same label) now. The stabilizer keeps
  `matchTrackIds: false` (0022) until M6.
- `SimulatedRobot`: fake ack/motion_done timing; a fake `dist_cm` that drives with `motor`; dropped
  replies, error replies, a missed pick, a hand, old firmware and link loss. Everything above is
  tested on it.
- The fake MaixCAM2 (0024) speaks this shape:
  - `STATUS`, `LOCK_DRIVE`, `UNLOCK_DRIVE`, `HOLD` and `STOP` are answered;
  - `PICK`, `MOVE_TO_BIN` and `DROP` reply `error: not_implemented` (a later task);
  - unknown commands reply `error: unknown_cmd`.

## In the app now

With `--dart-define=LIVE_SCAN=true --dart-define=R1=true`, the control screen:

- builds R1 on a `MaixCamRobot`;
- probes the link on every (re)connect;
- shows "R1: robot terhubung" or "R1: robot tidak terhubung" under the live-scan debug overlay.

The student-facing steps (bin question, reveal, position hints, "Ambil") are not on screen yet.
They come with the overlay work (M4), once R1-fw exists. Until then, R1 takes no lock in the app,
and the live scan works as before.

## Not in R1

- Emergency stop (next task).
- Teleop jogging, the manual sort mode, R2.
- The overlay layout (M4).
- The firmware side (R1-fw).

## Amendment 24 Oct (E1): HEARTBEAT and the emergency stop

- **`{"cmd": "HEARTBEAT"}`**: app → MaixCAM2 every 250 ms while connected. It has no `seq` and
  no reply. It feeds the MaixCAM2's 1 s watchdog ([0026](0026-emergency-stop-motion-gate.md)).
  Today's firmware ignores it.
- **The emergency stop** sends `STOP` and `motor 0,0` (repeated) from the app's motion gate,
  whether or not R1 is running.
  - R1's `emergencyStop` runs its safe exit but keeps driving locked, with no `UNLOCK_DRIVE`.
  - Only `resumeAfterStop` ("Lanjutkan") unlocks; a reconnect does not.
  - While the app is STOPPED, only `STOP`, `STATUS` and `HEARTBEAT` reach the MaixCAM2.
- R1's error exits (`robot_error`, `robot_unreachable`, `pick_failed`) put the app into STOPPED
  (`error`).
