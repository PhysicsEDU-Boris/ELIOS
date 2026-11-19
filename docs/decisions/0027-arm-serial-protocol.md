# 0027: Arm serial protocol, home, Cartesian hand controls and tags

- Status: Accepted for G2a; ESP32 implementation remains L2. The "MaixCAM2 to ESP32" section and
  its joint table are superseded by [0230](0230-sync-robotic-hand-sim.md) (robotic_hand_sim 75ab797).
- Date: 2026-10-26
- Builds on: [0023](0023-r1-command-link.md), [0026](0026-emergency-stop-motion-gate.md),
  [0029](0029-arm-reach-gripper.md).

## App to MaixCAM2

- `{"cmd":"HOME","seq":n}` requests the all-zero five-joint pose and opens the gripper.
  MaixCAM2 replies `ack` immediately and `motion_done` when its 60°/s travel estimate finishes.
  A busy arm returns `error` with `reason:"busy"`.
- `{"cmd":"servo","part":"reach|height","val":n}` uses integer `n` in 0..180. Each
  value step is one 2 mm Manual Override IK step: 0..90 moves −Y/−Z; 90 is neutral; 90..180
  moves +Y/+Z. J1 stays fixed, so the camera does not pan. The app sends the same `servo`
  command for `gripper`, with 0 open and 100 closed (0029). `servo part=base` remains
  debug-only J1 rotation.
- `lateral` is reserved but disabled. On this 5-DOF arm, moving the hand along world X requires
  J1, which pans the J1-mounted camera; holding J1 fixed makes the X IK step ineffective. The
  fake rejects `lateral` until a camera-independent lateral mechanism is available.
- The app sends HOME through the motion gate; it is blocked while STOPPED, ignored during R1
  SORTING, and paused by the existing Human_Hand → HOLD behavior. The student screen requires
  hold-to-confirm before it sends HOME; debug controls are not subject to that confirmation. This
  is a home request, not a safety-rated stop.

## MaixCAM2 to ESP32

The MaixCAM2 sends one newline-terminated ASCII line per arm target, in this exact order:
`D2,D3,D4,D5,D6,D8`. Values are absolute servo degrees. For the five arm joints,
`servo = home + sign × ratio × sim_angle`; ratio is 1:1. Firmware clamps to the effective
`robotic_hand_sim` limits and changes each joint at no more than 60°/s.

| Field | Function | Home | Sign | Effective sim range |
|---|---|---:|---:|---:|
| D2 | gripper | 10 (open) | — | 10..90; app width 0..100 maps linearly to 10..90 |
| D3 | J5 wrist yaw / roll | 90 | +1 | −90..+90° |
| D4 | J4 wrist pitch | 90 | −1 | −25..+90° |
| D5 | J3 Arm B | 180 | +1 | −180..0° |
| D6 | J2 Arm A | 90 | −1 | −50..+50° |
| D8 | J1 base | 90 | +1 | −90..+90° |

D7 mirrors D6 in firmware (`180 − D6`). The all-home line is `10,90,90,180,90,90\n`.
Gripper conversion is `10 + 0.8 × width`; it is not part of the five-joint angle mapping.
The 1:1 gear ratio for D8 (J1) is an assumption; the owner must confirm the real planetary gear.

## Boot, feedback and app assumptions

There is no servo-position feedback. Only ESP32 `setup()` writes the home line at power-on; a
MaixCAM2 reboot does not home the arm. The arm must be parked at home before power-off (owner
confirms this hardware rule). `motion_done` means the MaixCAM2's commanded travel-time estimate
has elapsed, not that a sensor verified the pose. `STATUS` adds `ee_mm:[x,y,z]` and `at_home`:
`ee_mm` is the J4 point (as in the sim's "EE position (J4)"); the fake reports it from the
current simulated angles. With no real feedback, hardware `ee_mm` is only an estimate from the
latest commanded angles. `at_home` reflects whether the commanded joint target is all zero and
the gripper target is open, not measured position.
After a camera reboot the app must treat the physical pose as unknown until it has a trusted
command history or an operator confirms home.

These home, sign and range values come from `hil_toolkit/hardware_mapping.py` in
`robotic_hand_sim`.

## Named tag-check poses

The fake was measured against the simulator's tag model and camera. Angles below are sim joints
`[J1,J2,J3,J4,J5]` in degrees; `inspect` is a measured visibility pose, not a firmware command.

| Pose | Sim joint angles | Visible arm tags |
|---|---|---|
| `home` | `[0,0,0,0,0]` | none |
| `inspect` | `[0,50,-120,90,-45]` | 0 and 1 |

HOME is joint-space travel and does not yet define a safe route from a bin. L4 must choose and
test a safe waypoint before bin-to-home motion is enabled.


## G2c acceptance: STATUS does not confirm HOME (2026-10-28)

`at_home:true` in STATUS describes a commanded target, not completion of the
app's pending HOME sequence. STATUS may refresh/clear EE coordinates and
invalidate confirmation when `at_home:false`; it must never establish HOME
confirmation or reset the slider cache. Only the matching successful HOME
`motion_done`, accepted by MotionGate, calls `RobotControlNotifier.resetToHome()`.
This also prevents STATUS after STOP, disconnect, rejection or timeout from
restoring a canceled HOME confirmation. STATUS polling after any motion completion
remains enabled for EE telemetry, including mismatched completions.
