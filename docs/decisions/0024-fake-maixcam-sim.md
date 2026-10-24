# 0024: A sim-backed fake MaixCAM2 for testing without the robot (T1)

- Status: Accepted (tooling; no app or firmware change)
- Date: 2026-10-24
- Builds on: [0020](0020-lock-rearm-rule.md), [0021](0021-manual-driving-orchestration.md),
  [0022](0022-detection-protocol-distance-tags.md). 0023 is reserved for R1's command link.
- Code: `tools/fake_maixcam/` (see its README).

## Decision

`tools/fake_maixcam/fake_maixcam.py` is a Python WebSocket server on port 8765. It speaks the
protocol of `firmware/maixcam2/main.py`, copied from that file:

- connect, ping/pong, start/stop stream, disconnect_ack;
- motor/servo are only logged, and set_resolution is ignored;
- the same frame fields, with detections refreshed every 2nd frame and held in between;
- `clean_image` and `clean_detections` on detection frames.

The app connects to it like the robot (config screen: `127.0.0.1:8765`).

**Its "robot" is the owner's simulator**, [robotic_hand_sim](https://github.com/3dbore/robotic_hand_sim),
loaded from `--sim-path`. It is not copied into this repo. It was tested against commit `9b2737e`
(2026-10-23).

- Frames come from the sim's offscreen `SimCalibrationCamera(640, 480)`. Its `camera_pose(θ1)`
  places the lens at (-54, -51.1, 86.2) mm, looking along -Y, level, turning with J1.
- At 640x480 its `f_y` is 503.17 px: exactly 0022's `(H/2)/tan(V/2)`.
- Scene items are upright photo cards on the floor (`images/<label>/`, or a generated
  placeholder).

**Detections are ground truth.**

- Each card's corners are projected with the sim camera's own `project()`. A box is emitted
  only when the card is in front of the lens and at least 30 % of it is inside the image.
- Optional noise: score jitter, flicker, periodic dropouts and label swap.
- P1 fields are computed from the true geometry:
  - `dist_cm`: along the optical axis on the floor, from the floor point below the lens to the
    card's nearest bottom point, which is what the box's bottom edge shows;
  - `lateral_cm`: of the bottom centre, positive to the right;
  - `track_id`: new each time an item appears;
  - `arm_tags`: ids 0 and 1, when a tag faces the lens and all its corners are in view.
- One flag (`p1: false` / `--old-firmware`) turns all P1 fields off.

**Scenarios are YAML files:** items, a timeline (appear, leave, set_label, noise, link_drop, arm),
and J1 targets that are reached at 60 deg/s. Ten scenarios ship (see the README).

- A link drop silences the connection (frames and pongs) and refuses new handshakes for `for_s`.
  This is what a WiFi loss looks like to the app's 8 s watchdog.

**Labels** come from `tools/fake_maixcam/labels.yaml`: the 10 names from the training set's
`data.yaml` (waste-dataset-v8, nc 10), in class_id order. `--check-labels` and a test compare them
with `main.py`'s `LABELS` and the app's `ScannedWaste.detectorLabels`. On 24 Oct all three were
identical: no mismatch.

**Command hook for R1**: since R1, it uses [0023](0023-r1-command-link.md)'s shape, `{"cmd", "seq"}` →
`{"event", "seq"}`. It answers `STATUS`, `LOCK_DRIVE`, `UNLOCK_DRIVE`, `HOLD` and `STOP`, and
replies `error: unknown_cmd` to other commands. Before R1, the shape was a placeholder:

- A handler table for `{"cmd": NAME, "id": n}`, replying `ack` / `motion_done` / `error`.
- `HOLD` and `J1_SWEEP` are implemented.
- `PICK`, `MOVE_TO_BIN`, `DROP`, `STOP` and `DRIVE` reply `error: not_implemented`. Their TODOs
  describe the intended behaviour: IK and 60 deg/s per joint for the arm, and moving the scene for
  DRIVE.

## Why

- R1 to R2 need repeatable tests of lock, re-arm, hand, link-loss and J1 behaviour, and the arm
  is not working yet.
- Rendering through the sim keeps the camera geometry identical to the owner's model and to 0022.
- Ground-truth boxes make every scenario deterministic for a given seed.

## Limits

- No occlusion: the cards and the arm never hide each other.
- No segmentation mask.
- The real model's misdetections are only approximated by the noise settings.
- `dist_cm` is exact here. The real camera still needs the calibration in 0022.

## Tests

`tools/fake_maixcam/test_fake_maixcam.py` (pytest, no hardware; the simulator is needed) covers:

- connect, ping/pong, motor/servo/set_resolution, disconnect;
- start/stop stream;
- the frame and detection fields, against `main.py` parsed with `ast`;
- P1 fields on and off, including `arm_tags`;
- `dist_cm` and `lateral_cm` against the 0022 formula within 1 cm, at J1 = 0 and 12 deg;
- link drop, the command hook, labels, and scenario validation.

Each test was break-checked against a mutated fake.
