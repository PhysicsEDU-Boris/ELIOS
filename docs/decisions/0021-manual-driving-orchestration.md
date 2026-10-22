# 0021: Manual driving, camera distance and the sorting orchestration (P1, R1, R2)

- Status: Proposed (owner decided 22 Oct, not built)
- Date: 2026-10-22
- Builds on: [0008](0008-live-scan-state-machine.md), [0012](0012-crop-identification-and-hazards.md),
  [0020](0020-lock-rearm-rule.md).

## Robot as it is

- Three bins: organik, anorganik, B3. The arm is not working yet.
- The student drives from the app's control screen. There is **no distance sensor**.
- The app can lock and unlock driving; it cannot move the wheels itself.

## Distance from the camera

- Floor bands at 20 / 30 / 40 / 60 cm, from the owner's 3D simulator (FOV H81 V51 D90).
  Simulator values are a design target. The real MaixCAM2 must be calibrated with objects at
  20, 30 and 40 cm.
- Valid only for objects on the floor, measured at the bottom edge of the box, from one fixed
  reference point.

## AprilTags on the arm

- id0 = gripper, id1 = arm, distance in mm. They are arm feedback, not object distance.
- A pick counts as done only when the tags show the gripper reached the expected range. Tags lost
  or never arriving means a timeout to a safe state.

## P1: protocol (do first)

- Optional per-detection `track_id` and `dist_cm`, optional per-frame `arm_tags`, all parsed as
  nullable. Old firmware must keep working.
- The stabilizer's `trackId` slot is fed, but lock and re-arm logic stays on overlap matching.
- Today none of these reach the app.

## R1: orchestration (after P1)

States:

1. SEARCHING
2. OBJECT_IN_VIEW: lock; driving locked; the screen says "Berhenti".
3. IDENTIFYING
4. CONFIRM: B3, or a detector/Gemma mismatch.
5. ASK_BIN
6. REVEAL
7. POSITION: `dist_cm` vs `PICK_BAND_CM` 20-40; small nudges allowed. If `dist_cm` is null, show a
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
  `heartbeat`.
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
