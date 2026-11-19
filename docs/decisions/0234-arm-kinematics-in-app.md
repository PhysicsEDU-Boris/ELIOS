# 0234 — Manual arm keys planned in the app, like robotic_hand_sim

Date: 19 November 2026. Branch `feat/arm-kinematics`, stacked on `feat/bin-tag-check` (0233).
Owner, 19 Nov: the arm calculations run in the app; the MaixCAM2 forwards poses to the ESP32
(next task: MaixCAM2 firmware with the DROP guard).

## What changed

Every manual arm key on the Control screen (phone and tablet) now asks `ArmPose` for a goal pose,
like the sim's `MainWindow._request`: the goal is clamped to each axis, checked against the joint
limits and the tank, and planned (`plan`: straight, else arm first, else base first). A refused
move is not sent; a snackbar says why (at most every 2 s). A sent move is `ARM_POSE`.

| Key | Before | Now |
|---|---|---|
| BASIS joystick | `servo base 0..180` | base servo angle, planned (tank: no turning behind with the arm low) |
| Height / Reach faders | `servo height/reach 0..180` (no meaning on the robot) | end effector up/down or along the heading, tool pitch kept (sim "Go to point"); ranges reach 40–320 mm, height 40–370 mm |
| Gripper fader | `servo gripper 0..100` | gripper servo `180 − (180 − closed) × width/100`, closed = 75 + Advanced offset |
| PICK | gripper 100 | close to 75 + offset (sim "Close") |
| RELEASE | gripper 0 | open 180 (sim "Open") |
| HOME | `HOME` | the planned way home as `ARM_POSE`, tracked like HOME (ack, motion_done, timeout = 5 s + move time) |

The fader and gripper positions now show the commanded pose (from FK), not the last slider value.

## Wire (app → MaixCAM2)

`{"cmd": "ARM_POSE", "seq": n, "path": [[F0..F5], ...]}`: one pose per leg, servo degrees in the
firmware's field order (Gripper, Wrist Yaw, Wrist Pitch, Arm B, Arm A, Base), one decimal,
**before trim and invert** (the MaixCAM2 applies the Advanced trims when it builds the ESP32 frame).
Replies `ack`, then `motion_done` after the last leg; `error` with a reason. A newer `ARM_POSE`
replaces one in flight (the sim's `go_path`). This amends 0230 §3 ("the app never sends servo
frames itself"): it still sends no ESP32 frames, but it now decides the joint angles.

## Unknown pose

After a STOP (the arm holds wherever it was) or an R1 sort (PICK and the bin sequence move it), the
app no longer knows the arm's pose: every manual move is refused with "Press HOME first", and HOME
falls back to the firmware's own `HOME`. Its `motion_done` makes the pose known again.

## Code

- `lib/services/robot/arm_kinematics.dart`: FK, tank check, `planPath`, `solve`, effective joint
  limits; a port of `hil/kinematics.py`. Pinned to the sim by `test/fixtures/arm_kinematics_golden.json`
  (`tools/arm_kinematics/make_golden.py`, sim 75ab797: 61 FK poses, 60 IK, 60 plans). Rerun it when
  the sim's arm changes.
- `lib/services/robot/arm_pose.dart`: axes table (hil/config.py), servo ↔ sim, `legSeconds`
  (hil/motion.py), `ArmPose` (plan, commit, base, height, reach, gripper, close, open, home).
- `MotionGate.armPose`, `MotionGate.home(path:, motion:)`, `RobotController.armPose`.
- Fake MaixCAM2: `ARM_POSE` plays the legs in the sim and logs a warning if a leg passes over the tank.

## Not done / known limits

- The real MaixCAM2 firmware ignores `ARM_POSE` (it answers no 0023 command yet): on the robot the
  arm keys move nothing until the firmware task.
- A refused BASIS step is not fed back to the stick's integrator (`ponytail:` in control_screen):
  the knob's angle can run ahead while refused; the next accepted step plans from the real goal.
- Every fader change sends one `ARM_POSE`; not throttled. Watch the WiFi on the robot.
- Wrist yaw has no key; it stays at home (90).
- `MotionGate.servo` and the debug sheet's other `servo` sliders are unchanged.

## Tests

`test/robot/arm_kinematics_test.dart` (against the sim's golden values; break-checked with a link
length and the tank height), `test/robot/arm_pose_test.dart` (9), `test/motion_gate_test.dart`
"planned manual arm moves" (2; the HOME timeout case break-checked), fake
`test_arm_pose_plays_the_apps_path`.
