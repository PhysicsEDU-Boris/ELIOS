# 0192: Floor distance guides and object positions from a floor AprilTag

- Status: Accepted (not robot-tested yet)
- Date: 2026-11-08
- Base: `feature/live-scan`
- Builds on: [0022](0022-detection-protocol-distance-tags.md), [0183](0183-wide-16-9-stream-measured-fx.md)

## Problem

robotic_hand_sim draws distance guides over its camera view (`hil_toolkit/widgets.py`
`add_distance_guides`): floor lines 20 / 30 / 40 / 60 cm ahead of the lens, with rails 6 cm either
side. ELIOS had only a guess: full-width rows from decision 0022's level camera (86.2 mm up), drawn
only when the firmware sent `dist_cm`. It never does, because the camera's pose over the floor was
never measured. So R1's pick band (20–28 cm) never had a distance.

The lens itself is calibrated (0183: fx 374, cx 303.9, cy 183.0 at 640x360, negligible
distortion). The missing piece is the floor: the lens height and its tilt and roll.

## Decision

- **Floor tag.** tag36h11 **id 2**, black square **80 mm**, laid flat on the floor in view.
  Control → **Calibrate floor** turns the camera's tag search on (the existing `arm_tags` switch),
  averages the tag's corners over up to 8 detection frames (4 s at most), and solves the floor from
  the tag homography and the 0183 intrinsics: floor normal in the camera frame plus the lens height.
  The result is saved on the device (`SharedPreferences`, `floor_camera_v1`). It stays valid until
  the camera mount moves. J1 yaw turns the camera about a near-vertical axis, so the floor stays
  the same.
- **Firmware.** `arm_tags` now also reports id 2, and every tag carries `corners` (4 points in
  stream pixels, in order around the tag). The tag search still runs on the half-size image (0183).
- **App computes positions.** With a calibrated floor, `WebSocketService` fills `distCm` /
  `lateralCm` (0022 meaning) for every box the firmware sends without `dist_cm`, from the box's
  bottom-centre pixel. Every consumer (HUD, R1, live scan) gets them from the same place.
- **HUD (desktop/tablet Control).** The guides are projected from the floor model like the sim's:
  a line at 20 / 30 / 40 / 60 cm, rails ±6 cm, bands red → amber → green, labels on alternating
  sides, and the 20–28 cm pick zone shaded on the floor. They show when the floor is calibrated or the
  firmware sends `dist_cm`. The target tag reads `Plastic · 24 cm · 3 cm ←`. The phone layout stays
  bare (R3).

## Consequences

- After a calibration, R1 gets real distances. POSITION then guides "forward / back" towards the pick
  band instead of showing the "Posisi sudah pas" button.
- Before a calibration nothing changes. No distances are invented, and the guides stay hidden.
- Accuracy depends on the tag's printed size (ruler-measure the black square; `floorTagMm` in
  `lib/services/robot/floor_camera.dart` and `TAG_SIZES_MM[2]` in the firmware) and on a flat floor.
  A box's bottom edge is where it touches the floor, so tall or overhanging items read a little far.
- Other stream sizes reuse the 640x360 intrinsics scaled by width (`ponytail:` note in
  `floor_camera.dart`). A mode that crops the sensor needs its own solve.

## Robot test (to do)

1. Flash `firmware/maixcam2/main.py`, print tag id 2 at 80 mm black, place it flat ~25 cm ahead.
2. Control → Calibrate floor → the snackbar shows height (expect ≈ 86 mm) and tilt.
3. Put an item on a ruler mark at 20 / 30 / 40 cm: the tag's cm should read within ~1 cm, and the
   item should sit on the matching guide line.
