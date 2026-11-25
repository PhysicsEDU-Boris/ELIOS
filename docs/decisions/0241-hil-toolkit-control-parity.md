# 0241: Arm controls, Advanced settings and HOME like the HIL toolkit

- Status: Accepted (code and tests 25 Nov 2026; robot check: see "Robot check").
- Date: 2026-11-25
- Source: robotic_hand_sim `arm-hil-toolkit-2.py` (`ProfiledMotion`, Joints tab, `_request`) and
  `hil/main_window.py` (`_request`, `_set_axis`, `go_home`, `_set_close_offset`), `hil/config.py`
  (trim, invert, gripper close offset), `hil/kinematics.py` (`plan`).
- Builds on: [0232](0232-advanced-settings.md), [0234](0234-arm-kinematics-in-app.md),
  [0235](0235-maixcam2-arm-bridge.md), [0240](0240-sim-control-settings.md).

## Goal

Owner, 25 Nov: Height, Reach and Base already move the real arm; make the rest of the arm
controls behave like the PC HIL toolkit, and make sure Advanced settings and HOME really work.

## What differed from the toolkit, and the fix

| # | Toolkit | ELIOS before | Now |
|---|---------|--------------|-----|
| 1 | HOME waits for the move (`remaining()`) | the app called HOME failed after 5 s; the firmware's own HOME (pose unknown, after a failed bin run) takes up to ~12 s at the default profile | the MaixCAM2's `ARM_POSE` / `HOME` ack carries `motion_s` (planned seconds, holds included); the app waits `motion_s` + 5 s |
| 2 | HOME again, or a slider during HOME, just replans (`go_home`, `_set_axis`) | the firmware answered `busy` to a second HOME and to `ARM_POSE` during its HOME | `ARM_POSE` and `HOME` replace each other on the MaixCAM2; a manual move ends the app's HOME wait (`home_interrupted`, reason `manual_move`) |
| 3 | `_request` plans from where the arm is now (`sim_cmd`) | the app plans from its last goal; while the arm was still on its way the MaixCAM2 refused that path with `tank` | the MaixCAM2 checks the app's path from where the arm is; if it would cross the tank it replans from there (same planner) and refuses only if that fails too |
| 4 | invert per axis, gripper included | Advanced settings ▸ Gripper "inverted" was saved but never used | CONFIG `gripInverted` inverts the gripper's wire angle (F0) |
| 5 | settings apply to the next frame | Save while STOPPED or offline only stored the settings on the phone; they never reached the robot | the gate keeps the last unsent CONFIG and sends it on the next connection or GO (not during a stop: a trim moves the held servos) |
| 6 | a new close offset re-closes a closed gripper (`_set_close_offset`) | the gripper stayed at the old closed angle until PICK was pressed again | a closed gripper follows the new offset at once |

STATUS now also reports `trims` and `inverted` (F0..F5, as the MaixCAM2 uses them), so a check can
see that a CONFIG arrived.

Kept on purpose (not toolkit behaviour):
- STOP holds the arm where it is (0026); the toolkit releases the servos.
- No gripper trim: the gripper has the close offset instead (0232).
- Nothing is sent to the ESP32 before the first move (0235: the servos stay as they booted).
- Joystick settings already applied live (`JoystickController.config`, 0232); unchanged.

## Wire changes

- `ARM_POSE` / `HOME` ack: `{"event":"ack","seq":n,"motion_s":7.93}`. Older apps ignore it.
- `STATUS` ack: `+ "trims": [6], "inverted": [6]`.
- `CONFIG`: `gripInverted` (bool) is now read; the rest is unchanged.
- Firmware package 1.4.2 (still m2c-arm-v3).

## Tests

- `firmware/maixcam2/test_arm_bridge.py`: HOME ack time and HOME/ARM_POSE replacing each other;
  a path planned from the app's goal replanned from the arm's pose; gripper invert + STATUS config
  + a trim showing on the next frame. All three fail on the old bridge.
- `test/motion_gate_test.dart`: firmware HOME timeout from `motion_s`; a manual move ends the HOME
  wait; CONFIG sent on GO / on connect. `test/robot/arm_pose_test.dart`: close offset follows.
  All four fail with the old behaviour.

## Robot check

See `docs/local-build-notes.md` (25 Nov, 0241).
