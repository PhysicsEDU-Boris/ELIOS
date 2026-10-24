# 0021: Manual driving, camera distance and the sorting orchestration (P1, R1, R2)

- Status: Proposed (owner decided 22 Oct, not built; amended 24 Oct, see "Amendment 24 Oct")
- Date: 2026-10-22
- Builds on: [0008](0008-live-scan-state-machine.md), [0012](0012-crop-identification-and-hazards.md),
  [0020](0020-lock-rearm-rule.md).

## Robot as it is

- Three bins: organik, anorganik, B3. The arm is not working yet.
- The student drives from the app's control screen. There is **no distance sensor**.
- The app can lock and unlock driving; it cannot move the wheels itself.

## Distance from the camera

- Floor bands at 20 / 30 / 40 / 60 cm, from the owner's 3D simulator (FOV H81 V51 D90).
  Simulator values are a design target. ~~The real MaixCAM2 must be calibrated with objects at
  20, 30 and 40 cm.~~ Calibration distances are 20, 25 and 28 cm (amendment a).
- Valid only for objects on the floor, measured at the bottom edge of the box. The reference
  point is the floor point directly below the lens, along the optical axis (amendment b; formulas
  in [0022](0022-detection-protocol-distance-tags.md)).

## AprilTags on the arm

- id0 = gripper, id1 = arm, distance in mm. They are arm feedback, not object distance.
- ~~A pick counts as done only when the tags show the gripper reached the expected range.~~
  Replaced by amendment d. Tags lost or never arriving means a timeout to a safe state.

## P1: protocol (do first)

- Optional per-detection `track_id`, `dist_cm` and `lateral_cm`, optional per-frame `arm_tags`,
  all parsed as nullable. Old firmware must keep working.
- The stabilizer's `trackId` slot is fed, but lock and re-arm logic stays on overlap matching.
- Built 24 Oct on the app side; the firmware spec is [0022](0022-detection-protocol-distance-tags.md).
  The firmware does not send the fields yet (camera not calibrated).

## R1: orchestration (after P1)

States:

1. SEARCHING
2. OBJECT_IN_VIEW: lock; driving locked; the screen says "Berhenti".
3. IDENTIFYING
4. CONFIRM: B3, or a detector/Gemma mismatch.
5. ASK_BIN
6. REVEAL
7. POSITION: `dist_cm` vs `PICK_BAND_CM` 20-28 (amendment a); small nudges allowed. If `dist_cm` is null, show a
   manual "Posisi sudah pas" button.
8. READY: the student presses "Ambil".
9. SORTING (arm), in parallel with OBJECT_QUESTIONS (2 questions).
10. WAIT_BOTH
11. RESUME: driving unlocked; re-arm per 0020.

Rules:

- The student's answer never changes the robot's bin; the detector, Gemma and the hazard veto
  decide.
- The arm never moves before REVEAL.
- Human_Hand pauses the arm.
- Every wait has a timeout: BIN 15 s, QUESTION 20 s, plus position, arm and wait-cap constants.
- Driving is unlocked on every exit path, including errors.

Interfaces:

- `RobotController`: `lockDrive`, `unlockDrive`, `pick`, `drop`, `moveToBin`, `stop`, `status`,
  `heartbeat` (the heartbeat exists only if the MaixCAM2 adds one, amendment e).
- `ArmFeedback`.
- `ObjectIdentity`: overlap now, `track_id` later.
- `SimulatedRobot` with fake `dist_cm`, tags and failures, and a stub `RealRobot`.

## R2 / M4.1: sort modes

- Automatic, or the student picks the bin and the robot executes it.
- Student mode: pre-drop check, hazard veto both ways, `MANUAL_MAX_TRIES` 2. Scoring: first try 1,
  retry 0.5, revealed 0.
- Teleop jogging is deferred until an emergency stop and workspace limits exist.

## Safety and conditions

- Emergency stop is a separate task and must exist before any real arm test.
- ByteTrack (M6) stays conditional on the two-object overlap test, which is not done.

## Bin mapping (unchanged)

| Detector label | Bin |
|---|---|
| Organic | organik |
| Paper, Paperboard, Cardboard, Plastic, Glass, Metal, Tetra_Pak | anorganik |
| E_Waste | B3 (hazard veto first) |
| Human_Hand | excluded |
| residu | anorganik |

Gemma's raw category is kept separately.

## Amendment 24 Oct (owner)

a. **`PICK_BAND_CM` 20-28** (provisional) replaces 20-40. It comes from the wrist reach of
   ~315 mm from the base axis, the gripper ~55 mm ahead, and the lens 51 mm ahead of the base
   axis. The nearest visible floor is ~181 mm ahead of the lens. Calibration distances: 20, 25
   and 28 cm.

b. **`dist_cm` reference point** = the floor point directly below the lens, measured along the
   optical axis.

c. **The camera turns with J1.** While SORTING, and for `ARM_SETTLE_S` after it (the value is set
   in R1), ignore lock and re-arm events, and ignore boxes that overlap the arm/gripper region.
   Turning the whole body with the wheels also moves the view, but that is driving, not J1.

d. **Tags cannot confirm a top-down pick**, because id0 faces the floor. A pick is done when both
   hold:
   - the object has left its floor spot, and
   - the commanded motion time has elapsed (firmware limit 60 deg/s).

   Tags are optional, and are read only at the inspect pose. This replaces the rule "tags show
   the gripper reached the range".

e. **Topology.**
   - The Android app is the logical master. It runs R1 (the stabilizer, the lock, the drive lock
     and "Ambil"). It talks only to the MaixCAM2, over the existing live-scan WiFi link. It sends
     high-level commands (for example PICK, DRIVE, LOCK_DRIVE) and receives detections,
     `arm_tags` and status back.
   - The MaixCAM2 is the hardware master. It handles vision, tags, `track_id` and `dist_cm`. It
     never drives a servo itself; it forwards commands over two UARTs:
     - ESP32 = the arm: all six servos, including J1 (D8, the base yaw of the arm and camera).
       - Line format `"D2,D3,D4,D5,D6,D8\n"`: gripper, wrist yaw, wrist pitch, arm B, arm A,
         base.
       - Each field is 0..180 deg; an empty field detaches that servo.
       - 9600 baud, 60 deg/s limit.
       - No feedback, no heartbeat and no stop command.
     - Arduino Uno = the wheels / chassis only.
   - Nothing plugs into the Mac. The macOS build stays a debug and visualization target.
   - `RobotController`'s heartbeat exists only if the MaixCAM2 adds one.

f. **Plan item 2.6** ("phone tells the ESP32", "ESP32 heartbeat") is superseded by (e). The phone
   never talks to the ESP32; the MaixCAM2 forwards commands to it.
