# 0241: Arm controls, Advanced settings and HOME like the HIL toolkit

- Status: Accepted; built and checked on the robot with the owner, 25 Nov 2026 (see "Robot check").
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
| 7 | (found on the robot) | after an ESP32 reset the board refused every move with `pose_unknown`, but the app still thought it knew the pose: arm keys did nothing and HOME was sent as a planned `ARM_POSE`, also refused | a STATUS with `servo: null` or a `pose_unknown` refusal marks the pose unknown (arm keys say "HOME first"); a planned HOME refused with `pose_unknown` falls back to the firmware HOME at once |

STATUS now also reports `trims` and `inverted` (F0..F5, as the MaixCAM2 uses them), so a check can
see that a CONFIG arrived.

Kept on purpose (not toolkit behaviour):
- STOP holds the arm where it is (0026); the toolkit releases the servos.
- No gripper trim: the gripper has the close offset instead (0232).
- Nothing is sent to the ESP32 before the first move (0235: the servos stay as they booted).
- Joystick settings already applied live (`JoystickController.config`, 0232); unchanged.

## Owner changes on the robot (25 Nov, evening)

After trying it, the owner asked for the sim's way of tuning:
- **Advanced settings apply live** (the sim's Joints tab): no Save, no discard prompt. Every
  change is stored on the phone and sent as CONFIG at once, at most every 100 ms while a slider
  moves, always ending with the last value (`FaderThrottle`); leaving the page sends a waiting
  step. While STOPPED or offline the change waits in the gate (item 5) and the page says so once.
- **No teacher PIN** (replaces the PIN of [0232](0232-advanced-settings.md)); the saved PIN field
  stays in the settings JSON but nothing asks for it.
- **YAW and PITCH faders** beside HEIGHT and REACH on the phone ARM card: each moves only its
  wrist servo across its range (`ArmPose.yaw` / `pitch`, planned like every move); Height and
  Reach then keep the tool angle they leave. Not added to the R2 tablet layout.
- "All control acceleration like the sim": the sim on this Mac has no saved Joints-tab profile, so
  it runs the default profile, which is what the robot already plays (`ProfiledMotion`, pinned by
  `test/fixtures/arm_profile_golden.json`). What differed was calibration: the sim's
  `calibration/hil_settings.json` has **Arm B trim +15°** and **close offset −0.5°**. Set on the
  phone with the owner's OK; the robot now uses trims F0..F5 = 0, 0, 0, 15, 0, 2 (Base +2 was
  already the owner's).

## Wire changes

- `ARM_POSE` / `HOME` ack: `{"event":"ack","seq":n,"motion_s":7.93}`. Older apps ignore it.
- `STATUS` ack: `+ "trims": [6], "inverted": [6]`.
- `CONFIG`: `gripInverted` (bool) is now read; the rest is unchanged.
- Firmware package 1.4.3 (still m2c-arm-v3).

## Tests

- `firmware/maixcam2/test_arm_bridge.py`: HOME ack time and HOME/ARM_POSE replacing each other;
  a path planned from the app's goal replanned from the arm's pose; gripper invert + STATUS config
  + a trim showing on the next frame. All three fail on the old bridge.
- `test/motion_gate_test.dart`: firmware HOME timeout from `motion_s`; a manual move ends the HOME
  wait; CONFIG sent on GO / on connect. `test/robot/arm_pose_test.dart`: close offset follows,
  pose unknown from STATUS / `pose_unknown`, YAW/PITCH moves. All fail with the old behaviour.
- `test/screens/advanced_settings_test.dart`: no PIN, no Save; a change is stored and sent at once,
  throttled to 10/s ending on the last value, sent on leaving, kept offline (6 of 7 fail without
  the live send). `test/widgets/phone_control_test.dart`: YAW/PITCH on screen at every phone size,
  right of REACH, report drags; Indonesian captions fit with four faders.

## Robot check (25 Nov, owner present; firmware 1.4.2, APKs 4fd41db then 4532173)

- CONFIG from the Mac before any move: trims, gripper invert and profile applied, saved to
  `/root/elios_arm_config.json` (it did not exist before: no CONFIG had ever reached this board),
  STATUS showed them; set back to neutral.
- HOME after an ESP32 power-on (pose unknown): first refused moves led to fix 7; with it, HOME
  went home (6 s firmware HOME, no `home_timeout`), STATUS `at_home`, ESP32 `out=` = HOME.
- Height up → HOME, HOME pressed again, Height → STOP mid-move → GO → HOME: every command acked
  (no `busy`, no `tank`), arm home each time.
- Trim saved while STOPPED reached the board on GO (STATUS trims). Live Advanced: Wrist Yaw trim
  and close offset follow the slider; YAW / PITCH move the wrist (owner: "all works").
- Sim calibration applied: ESP32 `out=` Arm B 194.8 (180 + 15), Base 92.1 at home; owner: right.
- **The MaixCAM2 rebooted on its own once** (about 23:43, around the 15° Arm B move); the ESP32
  then released all servos (195 bad frames during the reboot) and HOME re-engaged them. Same
  symptom as the reset when the servos first powered on (0240): likely a shared supply dipping
  under servo load. Open: separate supply for the servos.

Build details: `docs/local-build-notes.md` (25 Nov, 0241).

## Sorting after the quiz and the bin tags (26 Nov, owner present)

- **Sort starts by itself** (owner): the bin run waited for PICK UP behind the result page while
  it said "dropping". It now starts when the quiz is finished; after 3 s the arm takes the item
  to the AI's bin. The result page says "sorting…", then "Done: …" or "could not finish". The
  bin-check ticket says it happens after the quiz (`BinRunCue` ready / done / failed).
- **Calibration from robotic_hand_sim `958b185`** (`calibration/hil_settings.json`): Arm Base
  **inverted**, Wrist Yaw +8.5°, Arm B +15°, close offset 0. Set on the phone (Advanced) with the
  owner's OK. `camera_model.json` (fx 752.9 px on 1289 px) gives `CAM_HFOV_DEG` 81.1° (was the
  83° placeholder). The three bin sequences in that push are identical to `bin_sequences.json`.
- **MaixCAM2 app crash mid-sort**: the log showed `[Tags] on` after MOVE_TO_BIN, then a fresh
  start with no Python error: MaixPy's `find_apriltags` (already known to kill the app on a
  640x480 frame) also died at 320x180 on the real tank view. During a bin sequence the bin tags
  now come from OpenCV `cv2.aruco` AprilTag 36h11 on the full 640x360 frame in a worker thread
  (`BinTagSearch`, ~30 ms on the board, OpenCV releases the GIL; each result stamped with its
  frame time for the settle check; a detector error = no tag). Grip tags keep `find_apriltags`.
  No crash in the runs after it.
- Diagnostics (kept, `ponytail:`): during a sort the board logs `[Tags] bin search sees [...]` on
  each change and saves the searched view to `/root/elios_sort_view.jpg` once a second.
- **Robot runs**: Mid-Tank saw tag 4 on the way and tag 2 at its state point (OpenCV works on the
  real tags, ~40 px each). An Organik run stopped over a tank rim carrying **tags 2 and 4**, no
  tag 3, so DROP was refused (correct) and the arm went home. **Open**: the tank tags must match
  the sequences (Right = 3, Middle = 2, Left = 4, one per tank, where the recorded steps saw
  them), and the base invert from the PC calibration is not yet confirmed against the tanks.
- Tests: `test_clean_stream.py` (OpenCV result conversion, worker once-only + survives a detector
  error, stream uses the worker and never `find_apriltags` during a sort: fails on the old loop),
  `scan_quiz_pages_test.dart` (result page sorted / could not; ticket text).

