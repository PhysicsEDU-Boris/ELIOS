# 0022: Optional `track_id`, `dist_cm`, `lateral_cm` and `arm_tags` in the detection protocol (P1)

- Status: Accepted for the app side (parsing). The firmware part is a spec: the camera is not
  calibrated, so `firmware/maixcam2/main.py` does not send these fields yet.
- Date: 2026-10-24
- Builds on: [0020](0020-lock-rearm-rule.md), [0021](0021-manual-driving-orchestration.md).

## Message

Every new field is optional. When the firmware cannot compute a value it leaves the field out
(or sends `null`). It must never send `NaN` or `Infinity`: Python's `json.dumps` writes them,
but the app's `jsonDecode` rejects them and the whole frame is lost.

```json
{"img_w": 640, "img_h": 480, "image": "...",
 "detections": [{"x": 320, "y": 300, "w": 120, "h": 160, "label": "Plastic", "score": 0.9,
                 "track_id": 7, "dist_cm": 24.5, "lateral_cm": -3.2}],
 "arm_tags": [{"id": 0, "dist_mm": 82.5}, {"id": 1, "dist_mm": 140.0}]}
```

- `track_id` (int): the same id while the firmware tracker follows the object; a lost object
  gets a new id.
- `dist_cm` (float): the ground distance, measured from the floor point directly below the lens
  along the optical axis to the box's bottom edge.
- `lateral_cm` (float): the sideways offset from the optical axis on the same floor plane
  (positive = right in the image).
- `arm_tags` (per frame): only the tags seen in this frame. id 0 = gripper underside, id 1 = arm B
  rear face.

## App side (built in P1)

- `Detection` (`lib/services/websocket_service.dart`) has nullable `trackId`, `distCm` and
  `lateralCm`. `ArmTag.listFromJson` parses `arm_tags`. `WebSocketService.armTags` holds the
  last frame's tags. A missing value is null, and so is a wrong type or a non-finite number. A
  malformed tag entry is skipped. Old firmware parses exactly as before.
- `track_id` fills `TrackedDetection.trackId`. The live scan's stabilizer is built with
  `matchTrackIds: false`, so box overlap still decides identity for the lock. Re-arm (0020) only
  ever used overlap. Turning ids on is a separate decision (M6, after the two-object overlap test).
- Nothing reads `distCm`, `lateralCm` or `armTags` yet. R1 will.

## Geometry (facts)

- Lens at (-54, -51.1, 86.2) mm in the base frame, looking along -Y. Height h = 86.2 mm.
- FOV H81 V51 D90 (nominal).
- Nearest visible floor is about 181 mm ahead of the lens. That matches a level camera:
  86.2 / tan(25.5 deg) = 181 mm.
- The camera turns with base joint J1 (servo D8, the base yaw of the arm). `dist_cm` and
  `lateral_cm` are in the camera's own frame, so they stay valid at any J1 angle. Converting
  them to the base frame needs the J1 angle and the lens offset. Turning the whole body with the
  wheels also moves the view, but that is driving, not J1.

## How the MaixCAM2 computes `dist_cm` and `lateral_cm`

Use pixel coordinates of the streamed frame (W x H). The box's bottom edge is
`v_bottom = y + h_box/2` and its bottom centre is `u = x`.

Level camera (pitch 0):

- `f_y = (H/2) / tan(V/2)` and `f_x = (W/2) / tan(H_fov/2)`. These are nominal values;
  calibration replaces them.
- `d = f_y * h / (v_bottom - c_y)`
- `lateral = d * (u - c_x) / f_x`

Pitched camera (pitch θ down, general ray-plane intersection):

- `a = (u - c_x) / f_x`, `b = (v_bottom - c_y) / f_y`
- `t = h / (sin θ + b cos θ)`. When the denominator is ≤ 0, the ray never hits the floor, so the
  field is left out.
- `d = t * (cos θ - b sin θ)`, `lateral = t * a`. When θ = 0 this gives the level formulas.

Send `dist_cm` only when:

- the camera is calibrated;
- `v_bottom` is below the horizon (`v_bottom > c_y` plus a few pixels);
- the box's bottom edge is not clipped by the image's bottom border (clipped means the object is
  closer than the box shows).

The formula is valid only for objects standing on the floor.

Sensitivity (level camera, `f_y` ≈ 503 px at H = 480): about 1.4 mm per pixel at 25 cm. An error
of 1 mm in h is a 1.2 % error in d.

## What must be calibrated

- `f_y`, `c_y` (and `f_x`, `c_x` for `lateral_cm`) at the streamed resolution. The nominal FOV
  is 16:9, but the stream is 640x480, so the crop must be measured, not assumed.
- h (lens height above the floor) and the pitch θ, with the robot on its wheels on the working
  floor.
- Calibrate with J1 at its home angle, so the image's centre line is the arm's forward direction.
- Check with objects at 20, 25 and 28 cm (0021 `PICK_BAND_CM`), and record each measured
  distance next to its true distance.

## How AprilTag distances are read

- Call `find_apriltags` on the frame, passing the calibrated `fx, fy, cx, cy` and the tag family
  printed on the arm (TAG36H11 unless the owner says otherwise). Check the exact MaixPy API names
  on the device.
- `dist_mm = k * sqrt(x_t² + y_t² + z_t²)`, using the tag's translation. k is calibrated once
  with a tag at a known distance, because the translation is in tag-size units.
- Report only the ids 0 and 1, only when seen, and leave out tags that were not found.
- id 0 faces the floor during a top-down pick, so the tags cannot confirm a pick (0021). They
  are useful only at the inspect pose.

## `track_id`

The firmware tracker (for example MaixPy's ByteTracker, M6) gives each box an id. The app carries
the id but does not use it for identity until M6 is accepted.

## Topology (0021, section 7e)

- **Android app** = the logical master. It runs R1 (the stabilizer, the lock, the drive lock and
  "Ambil"). It talks only to the MaixCAM2, over the live-scan WiFi link. It sends high-level
  commands (for example PICK, DRIVE, LOCK_DRIVE) and receives detections, `arm_tags` and status.
- **MaixCAM2** = the hardware master. It handles vision, tags, `track_id` and `dist_cm`. It never
  drives a servo itself; it forwards commands over two UARTs:
  - **ESP32** = the arm: all six servos, including J1 (D8, the base yaw of the arm and camera).
    - Line format `"D2,D3,D4,D5,D6,D8\n"`: gripper, wrist yaw, wrist pitch, arm B, arm A, base.
    - Each field is 0..180 deg; an empty field detaches that servo.
    - 9600 baud, 60 deg/s limit.
    - No feedback, no heartbeat and no stop command.
  - **Arduino Uno** = the wheels / chassis only.
- Nothing plugs into the Mac. The macOS build stays a debug and visualization target.
- `RobotController.heartbeat` exists only if the MaixCAM2 adds one.

## Amendment 24 Oct (E1)

New optional per-frame field `arm_moving` (bool; `null` when missing or not a bool), for the J1
guard. It is specified in [0026](0026-emergency-stop-motion-gate.md).
