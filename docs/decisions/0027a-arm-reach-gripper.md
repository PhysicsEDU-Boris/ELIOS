# 0027a — Arm reach and gripper width

**Status:** accepted for G1; firmware mapping is specified for L2.

## Decision

- `servo part=reach val=<0..180>` moves the hand along the simulator's Y axis using the
  Manual Override's 2 mm damped-IK step. Value 0 is the -Y end, 90 is the current reach,
  and 180 is the +Y end. The fake clamps joint angles with `ase.clamp_angles` and holds J1
  during reach, so the camera remains governed only by `camera_pose(current_angles[0])`.
- `servo part=base` continues to control J1. Its small Base ◀ ▶ nudge is available only in
  the debug overlay.
- `servo part=gripper val=<0..100>` is width: 0 fully open and 100 fully closed. The fake
  considers values at or above 50 closed while rendering a continuously changing jaw gap.
- The physical gripper servo is D2, range 10–90 (open=10, close=90). Firmware L2 maps
  `0..100` to `10..90` and holds the commanded width.
- In the G1 flow, PICK UP sends gripper 100 and opens the quiz immediately after the button
  press; RELEASE sends gripper 0. The quiz-on-pick-up path remains opt-in until L5. L4 will
  wait for `motion_done` before progressing the flow.

## Rationale

ARM REACH describes Cartesian hand motion, not a camera pan. A 0–100 gripper value gives the
app and fake a simple width contract while preserving the fake's existing closed threshold;
the firmware owns conversion to the physical servo range.
